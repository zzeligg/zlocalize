# -*- encoding : utf-8 -*-

module ZLocalize
  module Translatable #:nodoc:

    module TranslatedAttributesSerializer #:nodoc:

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def serialize_translations(attribute_names,options = {})

          serialize :translated_attributes, HashWithIndifferentAccess

          set_default_locale_for_translations(options[:default_locale])

          [attribute_names].flatten.each do |attr_name|
            class_eval "def #{attr_name}(options = {})
                          read_translated_attribute('#{attr_name}',(options[:locale] || ZLocalize.locale).to_s, options[:fetch_default] == true)
                        end"
          end

          class_eval "after_initialize do
                        self.translated_attributes ||= HashWithIndifferentAccess.new
                      end

                      def translated_attributes=(value)
                        self.translations = value
                      end"

          include ZLocalize::Translatable::TranslatedAttributesSerializer::InstanceMethods
        end

      end

      module InstanceMethods

        def read_translated_attribute(attr_name,locale,fetch_default = true)
          s = self.translated_attributes[locale].try(:'[]',attr_name)
          if s.blank? && fetch_default
            unless (default_locale = evaluate_default_locale_for_translations).blank?
              if default_locale.to_s != locale.to_s
                return self.translated_attributes[default_locale].try(:'[]',attr_name)
              end
            end
          else
            return s
          end
        end

        alias :translate :read_translated_attribute

        def translations
          translated_attributes
        end

        def translations=(locales)
          locales.each do |locale,terms|
            self.translated_attributes[locale] ||= HashWithIndifferentAccess.new
            terms.each do |name,value|
              self.translated_attributes[locale][name] = value
            end
          end
        end

      end # module InstanceMethods

    end # module TranslatedAttributesSerializer
  end # module Translatable
end # module ZLocalize
