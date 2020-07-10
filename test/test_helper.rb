require 'rubygems'

require 'minitest/autorun'
require 'minitest/pride'

require File.join(File.dirname(__FILE__),'../lib/zlocalize')
# require 'I18n'

require 'active_record'
require File.join(File.dirname(__FILE__),'../lib/zlocalize/rails/active_record')
require File.join(File.dirname(__FILE__),'../lib/zlocalize/rails/translation_validator')

# other initialization here
I18n.available_locales = [:fr, :en]
I18n.locale = :en
I18n.default_locale = :en
I18n.load_path << File.join(File.dirname(__FILE__),'translations','fr.rails.yml')

ZLocalize.config.define_gettext_methods = true
ZLocalize.config.locales = {
  :fr => {
     :plural_select    => lambda { |n| n <= 0 ? 0 : (n > 1 ? 2 : 1) },
     :translations     => File.join(File.dirname(__FILE__),'translations/fr.strings.yml'),
     :titleize         => lambda { |s| s.capitalize.to_s },
     :convert_float    => lambda { |s| s.to_s.gsub(' ','').gsub(',','.') }
  },
  :en => {
     :plural_select     => lambda { |n| n <= 0 ? 0 : (n > 1 ? 2 : 1) },
     :translations     => File.join(File.dirname(__FILE__),'translations/en.strings.yml'),
     :convert_float     => lambda { |s| s.to_s.gsub(',','') }
  }
}

ActiveRecord::Base.configurations = { 'sqlite3' => {:adapter => 'sqlite3', :database => ':memory:'}}
ActiveRecord::Base.establish_connection(:sqlite3)

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::WARN

ActiveRecord::Schema.define(:version => 0) do

  create_table :item_with_translated_columns do |t|
    t.string  :name, :default => ''
    t.string  :description_fr, :default => nil
    t.string  :description_en, :default => nil
    t.decimal :amount, :precision => 10, :scale => 2
  end

  create_table :item_with_attached_translations do |t|
    t.string  :name, :default => ''
  end

  create_table :translations do |t|
    t.string :translated_type
    t.integer :translated_id
    t.string :name
    t.string :locale
    t.text :value
  end

  # ColItem class is used to test model with translated columns

end

# Translation model
require File.join(File.dirname(__FILE__),'../lib/zlocalize/rails/translation')

class ItemWithTranslatedColumns < ActiveRecord::Base
  translates_columns :description
  localize_decimal_attributes :amount
end

class ItemWithAttachedTranslations < ActiveRecord::Base
  has_translations
  accepts_nested_attributes_for :translations, :allow_destroy => true

  validates :description, translation: { required_locales: -> { [ :en, :fr ] } }
end

