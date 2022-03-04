# Memory representation of a list of translation strings in a given language
# Reads and writes each entry with a list of references to occurences in source files.

require 'yaml'

module ZLocalize

  def self.escape_ruby_string(s)
    s2 = s.to_s.dup
   #   s2.gsub!("'","\\\\'")  # no need to escape single quotes, since we will be writing only double-quoted strings
    s2.gsub!("\"","\\\"")
    s2.gsub!("\r\n","\n")
    s2.gsub!("\n\r","\n")
    s2.gsub!("\n","\\n")
    s2
  end

  def self.unescape_ruby_string(s)
    s2 = s.to_s
    s2.gsub!("\\'","'")
    s2.gsub!('\\"','"')
    s2.gsub!("\\n","\n")
    s2.gsub("\\","")
    s2
  end

   def self.clean_ruby_string(s)
    s2 = s.to_s
    if s2.size > 1
      # remove single or double quotes
      if (s2[0] == '"' && s2[s2.size-1] == '"') || (s2[0] == "'" && s2[s2.size-1] == "'")
        s2 = s2[1..s2.size-2].to_s
      end
    end
    unescape_ruby_string(s2)
  end

  class TranslationFileError < StandardError; end

  class TranslationEntry  #:nodoc: all
    attr_accessor :plural
    attr_accessor :source
    attr_accessor :translation
    attr_accessor :references
    attr_accessor :id
    attr_accessor :ignore

    def initialize(opts = {})
      # opts = HashWithIndifferentAccess.new(opts)
      @plural      = opts['plural']
      @source      = opts['source']
      @translation = opts['translation']
      @references  = opts['references']
      @id          = opts['id']
      @ignore      = opts['ignore']
    end

    def add_reference(ref)
      @references << ref unless @references.include?(ref)
    end

    def synchronize_references(entry)
      # first, remove references that are not present for other entry
      @references.delete_if { |ref| !entry.references.include?(ref) }
      # add all references from other entry (duplicates are avoided)
      entry.references.each { |ref| add_reference(ref) }
    end

    def to_yaml
      # write YAML ourselves, to allow UTF-8 strings as they are
      out = "entry_#{sprintf('%0.6d',id.to_i)}:\n" +
            "  id: #{@id}\n" +
            "  ignore: #{@ignore ? 'true' : 'false'}\n" +
            "  plural: #{@plural ? 'true' : 'false'}\n" +
            "  references:\n" +
               @references.map { |r| "    - #{r}" }.join("\n") + "\n" +
            "  source: #{data_to_yaml(@source)}\n" +
            "  translation: #{data_to_yaml(@translation)}\n"
      out.force_encoding("UTF-8")
    end

    def data_to_yaml(data)
      if data.nil?
        nil
      elsif data.is_a?(Array)
        "\n" +  data.map { |el| "    - \"#{ZLocalize.escape_ruby_string(el)}\"" }.join("\n")
      else
        "\"#{ZLocalize.escape_ruby_string(data)}\""
      end
    end

  end


  class TranslationEntryCollection < Hash  #:nodoc: all

    def add_entry(key,ref)
      if entry = self[key]
        entry.add_reference(ref)
      else
        entry = TranslationEntry.new(:source => key, :references => [ref], :translation => nil)
        self[key] = entry
      end
      entry
    end

    def synchronize_with(collection, purge = false)
      if purge
        # first, remove our entries that are not present in the other collection
        self.delete_if { |key,entry| !collection.key?(key) }
      end
      # add entries from the other collection that are not already in this collection
      collection.each do |key,entry|
        if self.key?(key)
          self[key].synchronize_references(entry)
        else
          self[key] = entry
        end
      end
    end

    # return an Array of entries, sorted by id
    def sort_by_id
      # Hash#sort will convert each item to an Array of 2 elements [key, value]
      sort { |entry1,entry2| entry1[1].id.to_i <=> entry2[1].id.to_i }.collect { |el| el[1] }
    end

   end


  class TranslationFile  #:nodoc: all

    attr_accessor :entries

    # regex to match Revision line
    REGEX_REVISION = /^#\s*Revision:\s+([0-9]+)/i

    # regex to match an entry delimiter
    REGEX_ENTRY = /^#\s*entry\s+([0-9]+)/

    # regex to match file and line number references for an entry
    REGEX_FILE_REF = /^#\s*file:\s+(.*?)\s*,\s*line\s+([0-9]{1,6})/

    # regex to match an optional # IGNORE line indicating that entry should be ignored
    REGEX_IGNORE_ENTRY = /^#\s*IGNORE/

    def self.load(file_name)
      f = new
      f.load(file_name)
      f
    end

    def initialize
       @entries = TranslationEntryCollection.new
    end

    def revision
      @revision.to_i > 0 ? @revision + 1 : 1
    end

    def list_entries
      @entries.each do |e|
        puts e.inspect
        puts "\n"
      end
    end

    def clear_entries
      @entries.clear
    end

    def add_entry(key,ref)
      @entries.add_entry(key,ref)
    end

    def synchronize_with(translation_file)
      @entries.synchronize_with(translation_file.entries)
    end

    def get_max_entry_id
      max_id = 0
      @entries.values.each do |e|
        max_id = e.id.to_i if e.id.to_i > max_id
      end
      max_id
    end

    def ensure_entry_ids
      next_id = get_max_entry_id + 1
      @entries.values.each do |e|
        unless e.id.to_i > 0
          e.id = next_id
          next_id += 1
        end
      end
    end

    def load(filename)
      if File.exist?(filename)
        content = File.open(filename,"r") { |f| f.read }
        read_yaml_header(content)
        begin
          entries = YAML::load(content)
        rescue StandardError => e
          raise TranslationFileError.new("Error reading ZLocalize TranslationFile #{filename} : #{e.message}")
        end
        if entries && !entries.is_a?(Hash)
          raise TranslationFileError.new("Invalid YAML translation file #{filename}\n\n#{entries.inspect}")
        end
      else
        raise TranslationFileError.new("Specified translation file does not exist: #{filename}")
      end
      entries ||= {}
      @entries.clear
      entries.each_pair do |k,entry|
        @entries[entry['source']] = TranslationEntry.new(entry)
      end
    end

    def read_yaml_header(content)
      re = /#\s*Revision:\s+([0-9]+)/i
      if m = re.match(content)
        @revision = m[1].to_i
      else
        @revision = 0
      end
    end

    def output_header
      out = "# Generated on: #{Time.now.strftime('%Y/%m/%d %H:%M')}\n"
      out << "# Revision: #{revision}\n\n"
      out
    end

    def to_yaml
      ensure_entry_ids
      out = output_header
      @entries.sort_by_id.each do |e|
        out << e.to_yaml
        out << "\n"
      end
      out
    end

    def non_translated_entries
      @entries.sort_by_id.collect { |e| e.translation.to_s.strip == "" }
    end

   end # class TranlationFile
end # module ZLocalize
