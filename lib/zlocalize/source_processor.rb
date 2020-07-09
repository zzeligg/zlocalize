require 'parser/all'
require 'action_view/template/handlers/erb'
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
      @stree = @parser.parse(content)
      process(@stree)
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
      if node.type == :send && node.children[0] == nil
        if node.children[1] == :_
          process_translate_call(node) and return
        elsif node.children[1] == :n_
          process_pluralize_call(node) and return
        end
      end
      node.children.each do |n|
        process(n)
      end
    end

    def process_translate_call(node)
      tc = { name: node.children[1].to_s,
             line_no: node.loc.selector.line,
             char_no: node.loc.selector.column+1 }
      # process the string parameter
      unless node.children[2].is_a?(AST::Node) || node.children[2].type != :str
        raise ArgumentError.new("First parameter to _() method must be a String")
      end
      tc[:parameter] = node.children[2].children[0]
      @translate_calls << tc
      for i in 3..node.children.size-1
        process(node.children[i])
      end
    end

    def process_pluralize_call(node)
      tc = { name: node.children[1].to_s,
             line_no: node.loc.selector.line,
             char_no: node.loc.selector.column+1 }
      # process the Array parameter
      unless node.children[2].is_a?(AST::Node) || node.children[2].type != :array
        raise ArgumentError.new("First parameter to n_() method must be an Array of String")
      end
      tc[:parameter] = process_string_array(node.children[2])
      @translate_calls << tc
      for i in 3..node.children.size-1
        process(node.children[i])
      end
    end

    def process_string_array(node)
      a = []
      for i in 0..node.children.size - 1
        if node.children[i].type == :str
          a << node.children[i].children[0]
        else
          raise ArgumentError.new("First parameter to n_() method must be and Array of String")
        end
      end
      a
    end


    def make_translation_entry(h)
      # if ['_','n_'].include?(@name)
      #   params = @parameters.dup
      # elsif @name == 'ZLocalize' && @sub_method.is_a?(IdentifierExpression) && ['pluralize','translate'].include?(@sub_method.name)
      #   params = @sub_method.parameters.dup
      # else
      #   return nil
      # end
      TranslationEntry.new('plural'     => h[:name] == 'n_',
                           'source'     => h[:parameter],
                           'references' => [ "#{@relative_filename}:#{h[:line_no]}" ])
    end

    # return a Hash of all translation entries we collected
    def translation_entries
      entries = {}
      @translate_calls.each do |c|
        e = make_translation_entry(c)
        if entries[e.source]
          entries[e.source].references += te.references
        else
          entries[e.source] = e
        end
      end
      entries
    end

  end

end