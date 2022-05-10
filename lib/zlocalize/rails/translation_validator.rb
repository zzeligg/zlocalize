class TranslationValidator < ActiveModel::EachValidator

  def initialize(options = {})
    # create a virtual attribute accessor for the expected translations
    options[:attributes].each do |attr_name|
      options[:class].attr_accessor attr_name
    end
    super
  end

  def evaluate_required_locales(locales,record,attr_name,value)
    case locales
      when Symbol then record.send(locales)
      when Array  then locales
      when String then [locales]
      else
         if locales.respond_to?("call")
            args = [record,attr_name,value].slice(0,locales.arity)
            locales.call(*args)
         else
            raise(
              ActiveRecord::ActiveRecordError,
              "Required locales need to be either an Array instance, a symbol/string (method to be called on the instance) " +
              "or a proc/method that returns an Array of locale codes"
            )
         end
    end
  end

  def validate_each(record, attr_name, value)
    configuration = { :message => :missing_translations,
                      :required_locales => record.respond_to?(:get_required_locales) ? :get_required_locales : [] }
    configuration.update(options)
    locales = evaluate_required_locales(configuration[:required_locales],record,attr_name,value)
    missing_locales = []
    if locales.is_a?(Array)
      locales.each do |loc|
        begin
          s = record.translate(attr_name.to_sym,loc)
        rescue ZLocalize::Translatable::TranslationError
          s = nil
        end
        missing_locales << loc if s.blank?
      end
    end
    if missing_locales.size > 0
      record.errors.add(attr_name, :missing_translation, :message => configuration[:message], :locales => missing_locales.to_sentence)
    end
  end

end
