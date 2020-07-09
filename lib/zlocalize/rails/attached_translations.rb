#
#  === Translation of attributes values for ActiveRecord ===
#
#  Allows a model to have multiple values (one for each given locale) stored for one or more attributes
#
#  Uses a Translation model, declared as a polymorphic association
#
#  Example use:
#
#  class Article < ActiveRecord::Base
#    ....
#    has_translations
#    ....
#  end
#
#
#  > @article = Article.new
#  > @article.insert_translations(:fr => { :title => "L'année en revue" }, :en => { :title => "The Year in Review" })
#  > @article.translate('title','fr')
#    => "L'année en revue"
#  > @article.translate('title','en')
#    => "The year in review"
#
#  It is also possible to declare the translations as nested_attributes:
#
#
#  has_translations
#  accepts_nested_attributes_for :translations, :allow_destroy => true
#
#  which would allow to assign translations from within a form (using fields_for helper).
#
#  params[:article][:translations_attributes] = [ { :locale => :fr, :name => 'title', :value => "L'année en revue" },
#                                                 { :locale => :en, :name => 'title', :value => "The Year in Review" } ]
#
module ZLocalize
  module Translatable #:nodoc:

    class TranslationError < StandardError #:nodoc:
    end

    module AttachedTranslations #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def has_translations
          has_many :translations, :as => :translated, :dependent => :destroy
          include ZLocalize::Translatable::AttachedTranslations::InstanceMethods
        end

      end

      module InstanceMethods

        def translate(attr_name,locale = nil)
          locale ||= ZLocalize.locale
          if tr = find_translation(attr_name,locale)
            tr.value
          else
            ''
          end
        end

        def add_translation(name,locale,value)
          if tr = find_translation(name,locale)
            tr.value = value.to_s
          else
            tr = translations.build(:translated => self, :name => name.to_s, :locale => locale.to_s, :value => value.to_s)
          end
          tr
        end

        # convenience method to accept a Hash containing the translations for multiple columns and
        # locales. +locales+ must have the locales as keys and its value is another Hash of name-value pairs.
        # Example:
        #    @article.insert_translations(
        #         { 'en' => { 'title'    => "What's new this week",
        #                     'synopsis' => "Learn what has happened this week in our little world"},
        #           'fr' => { 'title'    => "Quoi de neuf cette semaine",
        #                     'synopsis' => "Apprenez tout sur ce qui s'est passé cette semaine dans notre petit monde" }
        #
        # If you have user-generated content, for example, you can quickly
        # create a form to edit the translatable content as follows:
        # in the view:
        #    <label>Title in English</label>
        #    <%= text_field 'translations[en][title]', @article.translate('title','en') %>
        #    <label>Title in French</label>
        #    <%= text_field 'translations[fr][title]', @article.translate('title','fr') %>
        #
        # in the controller:
        #
        # def update
        #   ...
        #   @article.insert_translations(params['translations'])
        #   @article.save
        # end
        #
        # make sure your content is sanitized!
        #
        def insert_translations(locales = {})
          Translation.transaction do
            locales.each do |locale,terms|
              terms.each do |name,value|
                add_translation(name,locale,value)
              end
            end
          end
        end

        protected
          def find_translation(name,locale)
            translations.detect { |t| (t.name == name.to_s) && (t.locale == locale.to_s) }
          end
      end

    end
  end
end
