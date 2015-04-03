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

          [attribute_names].flatten.each do |attr_name|
            class_eval "def #{attr_name}(options = {})
                          read_translated_attribute('#{attr_name}',(options[:locale] || ZLocalize.locale).to_s)
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

        def read_translated_attribute(attr_name,locale)
          s = self.translated_attributes[locale]
          s.is_a?(Hash) ? s[attr_name] : nil
        end

        alias :translate :read_translated_attribute

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
