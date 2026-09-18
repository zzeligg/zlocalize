require 'prism'
# NOTE: This prevents Rails test environment to complain about this:
#       `ActionView::Template::Error: undefined method 'new' for module Erubi`
#       somehow Bundler or the autoload mechanism gets confused about which Erubi
#       implementation is defined
require 'action_view'
require 'action_view/template/handlers/erb/erubi'
require File.join(File.dirname(__FILE__),'translation_file')
require File.join(File.dirname(__FILE__),'harvester')

module ZLocalize

  class SourceProcessor

    # Methods recognized as translation calls when called without an explicit
    # receiver (bare calls), mapped to whether they yield plural entries.
    BARE_TRANSLATE_METHODS = { '_' => false, 'n_' => true }.freeze

    # Methods recognized as translation calls when called on the ZLocalize
    # constant, mapped to whether they yield plural entries.
    QUALIFIED_TRANSLATE_METHODS = { 'translate' => false, 'pluralize' => true }.freeze

    def initialize(filename, root, is_erb = false)
      @in_hash = 0
      @translate_calls = []
      @root = File.join(File.expand_path(root).downcase,'/') # add a trailing /
      @filename = File.expand_path(filename).downcase
      @relative_filename = @filename.gsub(@root,'')
      @line_offset = 0
      content = File.open(filename, "r") { |f| f.read }
      if is_erb
        content = ActionView::Template::Handlers::ERB::Erubi.new(content, escape: true, trim: true).src
        # Erubi compiles ERB to bare Ruby with top-level `yield`, which Prism
        # rejects (yield is only valid inside a method). Wrap in a method and
        # track the offset so reported line numbers still match the template.
        content = "def __zlocalize_erb__\n#{content}\nend"
        @line_offset = 1
      end
      begin
        process(content)
      rescue ArgumentError => ae
        raise ArgumentError.new("In #{filename} #{ae.message}")
      end
    end

    def process(content)
      parse_result = Prism.parse(content)
      raise ArgumentError.new("Syntax error: #{format_parse_errors(parse_result)}") unless parse_result.success?
      walk(parse_result.value)
    end

    def walk(node)
      return unless node.is_a?(Prism::Node)

      if node.is_a?(Prism::CallNode)
        if node.receiver.nil?
          plural = BARE_TRANSLATE_METHODS[node.name.to_s]
          if !plural.nil? && node.arguments && node.arguments.arguments.size >= 1
            record_call(node, plural) and return
          end
        elsif zlocalize_const?(node.receiver)
          plural = QUALIFIED_TRANSLATE_METHODS[node.name.to_s]
          if !plural.nil? && node.arguments && node.arguments.arguments.size >= 1
            record_call(node, plural) and return
          end
        end
      end

      node.compact_child_nodes.each { |child| walk(child) }
    end

    def record_call(node, plural)
      argument_nodes = node.arguments.arguments
      source = plural ? get_string_array_node_value(argument_nodes[0]) : get_string_node_value(argument_nodes[0])
      @translate_calls << { name: node.name.to_s,
                            line_no: node.message_loc.start_line - @line_offset,
                            char_no: node.message_loc.start_column + 1,
                            parameter: source }
      # keep harvesting inside any nested arguments (e.g. options hashes containing
      # further translation calls)
      argument_nodes[1..].each { |child| walk(child) } if argument_nodes.size > 1
    end

    def zlocalize_const?(node)
      node.is_a?(Prism::ConstantReadNode) && node.name.to_s == 'ZLocalize'
    end

    def get_string_node_value(node)
      unless string_node?(node)
        raise ArgumentError.new("On line #{node.location.start_line} at column #{node.location.start_column+1} : String Expected but got: #{node.inspect}")
      end
      return node.unescaped
    end

    def get_string_array_node_value(node)
      unless node.is_a?(Prism::ArrayNode)
        raise ArgumentError.new("On line #{node.location.start_line} at column #{node.location.start_column+1} : Array expected but got: #{node.inspect}")
      end
      node.elements.map { |element| get_string_node_value(element) }
    end

    def string_node?(node)
      node.is_a?(Prism::StringNode)
    end

    def format_parse_errors(parse_result)
      parse_result.errors.map do |error|
        "line #{error.location.start_line}: #{error.message}"
      end.join("\n")
    end

    # return a Hash of all translation entries we collected
    def translation_entries
      entries = {}
      @translate_calls.each do |c|
        e = make_translation_entry(c)
        if entries[e.source]
          entries[e.source].references += e.references
        else
          entries[e.source] = e
        end
      end
      entries
    end

    def make_translation_entry(h)
      TranslationEntry.new('plural'     => h[:name] == 'n_' || h[:name] == 'pluralize',
                           'source'     => h[:parameter],
                           'references' => [ "#{@relative_filename}:#{h[:line_no]}" ])
    end

  end

end
