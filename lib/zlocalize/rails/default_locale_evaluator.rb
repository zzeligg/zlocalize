# -*- encoding : utf-8 -*-
module ZLocalize
  module Translatable
    module DefaultLocaleEvaluator

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

        cattr_reader :default_locale_for_translations

        def set_default_locale_for_translations(value)
          @@default_locale_for_translations =
            case value
              when nil then nil
              when Symbol, String then value.to_sym
              else
                raise(
                  Zigotos::Translatable::TranslationError,
                    "default_locale option must be either a String or a Symbol representing a method on this class (trying to set it to a #{value.class.name})"
                )
            end

          include ZLocalize::Translatable::DefaultLocaleEvaluator::InstanceMethods
        end
      end

      module InstanceMethods

        def evaluate_default_locale_for_translations
          unless self.class.default_locale_for_translations.blank?
            self.send(self.class.default_locale_for_translations)
          else
            nil
          end
        end

      end # module InstanceMethods

    end # module DefaultLocaleEvaluator
  end # module Translatable
end # module ZLocalize