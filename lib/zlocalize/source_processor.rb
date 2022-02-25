require 'parser/all'
require 'action_view/template/handlers/erb/erubi'
require File.join(File.dirname(__FILE__),'translation_file')
require File.join(File.dirname(__FILE__),'harvester')

module ZLocalize

  class SourceProcessor

    def initialize(filename, root, is_erb = false)
      @in_hash = 0
      @translate_calls = []
      @root = File.join(File.expand_path(root).downcase,'/') # add a trailing /
      @filename = File.expand_path(filename).downcase
      @relative_filename = @filename.gsub(@root,'')
      content = File.open(filename, "r") { |f| f.read }
      if is_erb
        content = ActionView::Template::Handlers::ERB::Erubi.new(content, escape: true, trim: true).src
      end
      @parser = create_parser_for_ruby_version
      begin
        @stree = @parser.parse(content)
        process(@stree)
      rescue ArgumentError => ae
        raise ArgumentError.new("In #{filename} #{ae.message}")
      end
    end

    def create_parser_for_ruby_version
      md = RUBY_VERSION.match(/^(\d)\.(\d)/)
      begin
        kls = Object.const_get('Parser').const_get("Ruby#{md[1]}#{md[2]}")
      rescue
        raise "Unsupported Ruby version #{RUBY_VERSION}"
      end
    end

    def process(node)
      return unless node.is_a?(AST::Node)
      if node.type == :send
        if node.children[0] == nil
          if node.children[1] == :_
            process_translate_call(node) and return
          elsif node.children[1] == :n_
            process_pluralize_call(node) and return
          end
        elsif is_zlocalize_const?(node)
          if node.children[1] == :translate
            process_translate_call(node) and return
          elsif node.children[1] == :pluralize
            process_pluralize_call(node) and return
          end
        end
      end
      node.children.each do |n|
        process(n)
      end
    end

    def is_zlocalize_const?(node)
      return node.is_a?(AST::Node) && node.type == :const && node.children[1] == :ZLocalize
    end

    def get_string_node_value(node)
      unless node.is_a?(AST::Node) && node.type  == :str
        raise ArgumentError.new("On line #{node.loc.selector.line} at column #{node.loc.selector.column+1} : String Expected but got: #{node.inspect}")
      end
      return node.children[0]
    end

    def get_string_array_node_value(node)
      unless node.is_a?(AST::Node) || node.type != :array
        raise ArgumentError.new("On line #{node.loc.selector.line} at column #{node.loc.selector.column+1} : Array expected but got: #{node.inspect}")
      end
      a = []
      for i in 0..node.children.size - 1
        a << get_string_node_value(node.children[i])
      end
      a
    end

    def process_translate_call(node)
      @translate_calls << { name: node.children[1].to_s,
                            line_no: node.loc.selector.line,
                            char_no: node.loc.selector.column+1,
                            parameter: get_string_node_value(node.children[2]) }
      for i in 3..node.children.size-1
        process(node.children[i])
      end
    end

    def process_pluralize_call(node)
      @translate_calls << { name: node.children[1].to_s,
                            line_no: node.loc.selector.line,
                            char_no: node.loc.selector.column+1,
                            parameter: get_string_array_node_value(node.children[2]) }
      for i in 3..node.children.size-1
        process(node.children[i])
      end
    end

    def make_translation_entry(h)
      TranslationEntry.new('plural'     => h[:name] == 'n_' || h[:name] == 'pluralize',
                           'source'     => h[:parameter],
                           'references' => [ "#{@relative_filename}:#{h[:line_no]}" ])
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

  end

end
