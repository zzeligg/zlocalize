#  == Localized Decimal Attributes ==
#
# Provides a way to ensure Float attributes on ActiveRecord are converted to the internal format
# used by Ruby and Rails.
#
# Each locale defines a method to convert a String representing a float in a given locale into an actual Float
#
# Example with :fr (French) locale:
#
# 1) configuration (somewhere in an initializer):
#
#  ZLocalize.config.locales = {
#  :fr => {
#     :plural_select    => lambda { |n| n <= 0 ? 0 : (n > 1 ? 2 : 1) },
#     .....
#     :titleize         => lambda { |s| s.capitalize.to_s },
#     :convert_float    => lambda { |s| s.to_s.gsub(' ','').gsub(',','.') }
#  },
#
# 2) An Order model:
#
#   class Order < ActiveRecord::Base
#      ....
#      localize_decimal_attributes [:sub_total, :taxes]
#      ....
#   end
#
#
# 3) This allows to assign attributes with their French representation of a decimal number:
#
#  > order.attributes = {:sub_total => "1 222,54", :taxes => "1,23" }
#  > order.sub_total   # => 1222.54
#  > order.taxes       # => 1.23
#
#
module ZLocalize
  module Translatable #:nodoc:

    module LocalizedDecimalAttributes #:nodoc:

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def localize_decimal_attributes(column_names)

          [column_names].flatten.each do |col_name|
            class_eval "def #{col_name}=(value)
                          write_localized_decimal_attribute('#{col_name}',value)
                        end"
          end

          include ZLocalize::Translatable::LocalizedDecimalAttributes::InstanceMethods
        end
      end

      module InstanceMethods

        def write_localized_decimal_attribute(col_name,value,locale = nil)
          s = value.nil? ? nil : ZLocalize.convert_float(locale || ZLocalize.locale,value)
          self.send(:write_attribute, col_name,s)
        end

      end # module InstanceMethods

    end # module TranslatedColumns
  end # module Translatable
end # module ZLocalize




