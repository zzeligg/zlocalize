# -*- encoding : utf-8 -*-

class TranslationValidator < ActiveModel::EachValidator

  def evaluate_required_locales(locales,record,attr_name,value)
    case locales
      when Symbol then record.send(locales)
      when Array  then locales
      when String then [locales]
      else
         if locales.respond_to?("call")
           locales.call(record,attr_name,value)
         else
            raise(
              ActiveRecord::ActiveRecordError,
              "Required locales need to be either an Array instance, a symbol/string (method to be called on the instance) " +
              "or a proc/method that returns an Array of locale codes"
            )
         end
    end
  end

  def validate_each(record,attr_name,value)
    configuration = { :message => 'is missing its translation in {{locales}}',
                      :required_locales => record.respond_to?(:get_required_locales) ? :get_required_locales : [] }
    configuration.update(options)
    locales = evaluate_required_locales(configuration[:required_locales],record,attr_name,value)
    missing_locales = []
    if locales.is_a?(Array)
      locales.each do |loc|
        begin
          s = record.translate(attr_name,loc)
        rescue ZLocalize::Translatable::TranslationError
          s = nil
        end
        missing_locales << loc if s.blank?
      end
    end
    if missing_locales.size > 0
      record.errors.add(attr_name, configuration[:message], { :locales => missing_locales.to_sentence })
    end
  end

end
