# -*- encoding : utf-8 -*-

require 'yaml'
require 'zlocalize/translation_file'
require 'zlocalize/config'
require 'i18n'

module ZLocalize

  class MissingTranslationDataError < StandardError

    def initialize(locale, key, options)
      super "No translation exists in '#{locale}' for key \"#{key}\""
    end

  end

  @@load_mutex = Mutex.new

  class << self

    INTERPOLATE_MATCH = /(\\)?\{\{([^\}]+)\}\}/
    SCOPE_MATCH = /(.*?)(\\)?::(.+)/

    DEFAULT_PLURAL_SELECT_PROC = lambda { |n| n <= 0 ? 0 : (n > 1 ? 2 : 1) }
    DEFAULT_TITLEIZE_PROC      = lambda { |s| s.to_s.titleize }
    DEFAULT_CONVERT_FLOAT_PROC = lambda { |s| s.to_s.gsub(",", "") }

    def config
      @config ||= ZLocalize::Config.new
    end

    def locale
      I18n.locale
    end

    def locale=(value)
      I18n.locale = value
    end

    def default_locale
      I18n.default_locale
    end

    def default_locale=(value)
      I18n.default_locale = value
    end

    def translate(key, options = {})
      loc = options[:locale] || self.locale
      translate_with_locale(loc,key,options)
    end
    alias :t :translate

    def pluralize(key,count,options = {})
      loc = options[:locale] || self.locale
      pluralize_with_locale(loc,key,count,options)
    end
    alias :p :pluralize

    # Change locale inside a block
    def switch_locale(new_locale,&block)
      @@switch_locale_stack ||= []
      if block_given?
        @@switch_locale_stack.push self.locale
        self.locale = new_locale
        yield
        self.locale = @@switch_locale_stack.pop
      else
        self.locale = new_locale
      end
    end

    def translate_with_locale(locale, key, options = {})
      entry = lookup(locale,"#{key}")
      if entry.nil?
        if (default = options.delete(:default))
          entry = default
        elsif (options.delete(:return_source_on_missing) || @return_source_on_missing) == true
          entry = remove_scope(key)
        else
          raise ZLocalize::MissingTranslationDataError.new(locale, key, options)
        end
      end
      return interpolate(locale, entry, options).html_safe
    end

    # n_(["...","...","..."],count)
    def pluralize_with_locale(locale, key, count, options = {})

      entry = lookup(locale,key)
      if entry.nil?
        if (default = options.delete(:default))
          entry = default
        elsif (options.delete(:return_source_on_missing) || @return_source_on_missing) == true
          entry = key
        else
          raise ZLocalize::MissingTranslationDataError.new(locale,key,options)
        end
      end
      n = translation_procs[locale.to_sym][:plural_select].call(count)
      options[:count] ||= count
      return interpolate(locale, entry[n], options).html_safe
    end

    def titleize(locale,s)
      translation_procs[locale.to_sym][:titleize].call(s).html_safe
    end

    def convert_float(locale,s)
      translation_procs[locale.to_sym][:convert_float].call(s)
    end

    def multi_lookup(locale,values,options = {})
      result = {}
      values.each do |val|
        s = lookup(locale,"#{val}")
        result[val] = s.html_safe unless s.nil?
      end
      result
    end

    # Interpolates values into a given string.
    #
    #   interpolate "file {{file}} opened by \\{{user}}", :file => 'test.txt', :user => 'Mr. X'
    #   # => "file test.txt opened by {{user}}"
    #
    # Note that you have to double escape the <tt>\\</tt> when you want to escape
    # the <tt>{{...}}</tt> key in a string (once for the string and once for the
    # interpolation).
    def interpolate(locale, string, values = {})
      return string unless string.is_a?(String)

      result = string.gsub(INTERPOLATE_MATCH) do
        escaped, pattern, key = $1, $2, $2.to_sym

        if escaped
          "{{#{pattern}}}"
        elsif !values.include?(key)
          raise ArgumentError, "The #{key} argument is missing in the interpolation of '#{string}'"
        else
          values[key].to_s
        end
      end

      result
    end

    def initialized?
      @initialized ||= false
    end

    def reload!(force = false)
      if force || !@initialized || (self.config.reload_per_request[Rails.env.to_sym] == true)
        @initialized = false
        @translations = nil
        @translation_procs = nil
      end
    end

    def locales
      init_translations unless initialized?
      translations.keys.map { |k| k.to_s }
    end

    alias :available_locales :locales

    def translations
      init_translations unless initialized?
      @translations
    end

    def translation_procs
      init_translations unless initialized?
      @translation_procs
    end

    protected
      # init_translations manipulates the translation data and is triggered by lazy-loading, meaning
      # that on a busy multi-threaded environment, you might get 2 different threads trying to load the
      # data concurrently. Therefore, this method is wrapped inside a mutex, which effectively ensures
      # only 1 Thread will initialize the translation data Hash.
      # The rest of all operations on translation data is read-only, so no concurrency issues except here
      def init_translations
        @@load_mutex.synchronize do
          unless @initialized
            @translation_procs = {}
            @translations = {}

            config.locales.keys.each do |locale|
              cfg = self.config.locales[locale]
              loc = locale.to_sym
              @translation_procs[loc] = {
                :plural_select => cfg[:plural_select].is_a?(Proc) ? cfg[:plural_select] : DEFAULT_PLURAL_SELECT_PROC,
                :titleize      => cfg[:titleize].is_a?(Proc) ? cfg[:titleize] : DEFAULT_TITLEIZE_PROC,
                :convert_float => cfg[:convert_float].is_a?(Proc) ? cfg[:convert_float] : DEFAULT_CONVERT_FLOAT_PROC,
              }
              files = [cfg[:translations]].flatten.compact
              load_translations(loc,files)
            end

            @return_source_on_missing = config.return_source_on_missing[Rails.env.to_sym]

            @initialized = true
          end
        end
      end

      def load_translations(locale,filenames)
        @translations ||= {}
        @translations[locale] ||= {}
        filenames.each do |file|
          unless file.nil?
            tf = ZLocalize::TranslationFile.new
            tf.load(file)
            tf.entries.each do |key,entry|
              @translations[locale][entry.source] = entry.translation unless entry.ignore || entry.translation.to_s.empty?
            end
          end
        end
      end

      def lookup(locale, key)
        return unless key
        init_translations unless @initialized
        return @translations[locale.to_sym][key]
      end

      def remove_scope(key)
        return key unless key.is_a?(String)

        result = key.gsub(SCOPE_MATCH) do
          scope, escaped, unscoped = $1, $2, $3
          if $2 # escaped with \\::
            # $~[0]
            scope + '::' + $3
          else
            $3
          end
        end
      end

  end # class << self

end # module ZLocalize

