# -*- encoding : utf-8 -*-
module ZLocalize

  class Config

    attr_reader :reload_per_request
    attr_reader :return_source_on_missing
    attr_reader :reload_per_request
    attr_reader :locales
    attr_reader :define_gettext_methods

    def initialize
      @reload_per_request = { :development => true, :test => false, :production => false, :staging => false }
      @return_source_on_missing = { :development => true, :test => false, :production => false, :staging => false }
      @locales = {}
      @use_global_gettext_methods = true
    end

    def reload_per_request=(value)
      if value === true || value === false
        [:development,:test,:production,:staging].each do |env|
          @reload_per_request[env] = value
        end
      elsif value.is_a?(Hash)
        @reload_per_request.merge!(value)
      end
    end

    def return_source_on_missing=(value)
      if value === true || value === false
        [:development,:test,:production,:staging].each do |env|
          @return_source_on_missing[env] = value
        end
      elsif value.is_a?(Hash)
        @return_source_on_missing.merge!(value)
      end
    end

    def locales=(value)
      @locales = value
    end

    def define_gettext_methods=(value)
      @define_gettext_methods = value ? true : false
      please_define_gettext_methods if @define_gettext_methods
    end

    def please_define_gettext_methods
      Object.class_eval <<-EOV
         def _(key,options = {})
           ZLocalize.translate(key, options)
         end

         def n_(key,count,options = {})
           ZLocalize.pluralize(key,count,options)
         end
      EOV
    end

  end # class Config

end # module ZLocalize
