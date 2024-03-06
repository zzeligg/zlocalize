#
# === Translated columns ====
#
#  Allows an ActiveRecord Model to declare multiple values (one for each locale) for given attributes.
#  This module stores the values of each locale in table columns, such as:
#
#    create_table :articles do |t|
#      t.string  :title_fr, :default => ''
#      t.string  :title_en, :default => ''
#      t.text    :content_fr
#      t.text    :content_en
#    end
#
#    class Article < ActiveRecord::Base
#      ...
#      translates_columns [:title, :content]
#
#    end
#
#    > @article = Article.new({ :title_fr => "L'année en revue", :title_en => "The Year in Review" })
#    > I18n.locale = :fr
#    > @article.title
#      => "L'année en revue"
#    > I18n.locale = :en
#    > @article.title
#      => "The Year in Review"
#
module ZLocalize
  module Translatable #:nodoc:

    module TranslatedColumns #:nodoc:

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def translates_columns(*column_names)

          [column_names].flatten.each do |col_name|
            class_eval "def #{col_name}(options = {})
                          read_translated_column('#{col_name}',(options[:locale] || ZLocalize.locale),options[:fetch_default] == true)
                        end"
          end

          include ZLocalize::Translatable::TranslatedColumns::InstanceMethods
        end
      end

      module InstanceMethods

        def read_translated_column(col_name,locale,fetch_default = true)
          s = self.send("#{col_name}_#{locale}")
          if !s.nil?
            return s
          elsif fetch_default == true
            return self.send("#{col_name}_#{ZLocalize.default_locale}")
          end
          nil
        end

      end # module InstanceMethods

    end # module TranslatedColumns
  end # module Translatable
end # module ZLocalize




