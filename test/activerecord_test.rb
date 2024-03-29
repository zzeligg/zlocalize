# -*- encoding : utf-8 -*-
require_relative './test_helper'

# NOTE: the calls to `_()` in this file map to Minitest's DSL Object wrapper.
# ZLocalize `_()` method is not used

describe "ZLocalize ActiveRecord With Translated Columns" do

  it "must return the attribute value in the current locale" do
    i = ItemWithTranslatedColumns.create(:description_en => "English description", :description_fr => "Description française")
    id = i.id
    i = ItemWithTranslatedColumns.find(id)
    ZLocalize.locale = :en
    _(i.description).must_equal "English description"
    ZLocalize.locale = :fr
    _(i.description).must_equal "Description française"
  end

  it "must return the attribute value in default locale when no value exists for current locale" do
    i = ItemWithTranslatedColumns.create(:description_en => "English description")
    id = i.id
    i = ItemWithTranslatedColumns.find(id)
    ZLocalize.locale = :fr
    _(i.description(:fetch_default => true)).must_equal "English description"
    _(i.description(:fetch_default => false)).must_be_nil
  end

end

describe "ZLocalize ActiveRecord Decimal Attributes" do

  it "must return the correct float value from another locale (French)" do
    ZLocalize.locale = :fr
    i = ItemWithTranslatedColumns.new(:amount => "1 234,567")
    _(i.amount.to_f).must_equal 1234.57
  end

  it "must return the correct float value from a formatted float in English" do
    ZLocalize.locale = :en
    i = ItemWithTranslatedColumns.new(:amount => "234,000.567")
    _(i.amount).must_equal 234000.57
  end

end

describe "ZLocalize ActiveRecord Attached Translations" do

  it "must return translation of description in English on a new_record which calls #add_translation" do
    i = ItemWithAttachedTranslations.new
    i.add_translation('description','en',"English name")
    _(i.translate('description','en')).must_equal "English name"
    _(i.translations.size).must_equal 1
  end

  it "must return translation of description in English on a saved record" do
    i = ItemWithAttachedTranslations.new
    i.add_translation('description','en','English name')
    i.save(validate: false)
    # verify that a Translation exists for our item
    _(i.translations.where(:locale => 'en', :name => 'description').first.value).must_equal "English name"
  end

  it "must return a missing translation validation error for description in French on a saved record" do
    i = ItemWithAttachedTranslations.new
    i.add_translation('description','en','English name')
    i.valid?
    # verify that a Translation exists for our item
    _(i.errors[:description]).wont_be_empty
  end


  it "must create the correct translations when assigned through insert_translations" do
    i = ItemWithAttachedTranslations.new
    i.insert_translations({ :fr => { :title => "Nom", :description => "Description en français" },
                            :en => { :title => "Name", :description => "Description in English" } })
    i.save
    id = i.id
    i = ItemWithAttachedTranslations.find(id)
    I18n.locale = :en
    result = "#{i.translate('title')}-#{i.translate('description')}"
    I18n.locale = :fr
    result = result + "-#{i.translate('title')}-#{i.translate('description')}"
    _(result).must_equal "Name-Description in English-Nom-Description en français"
    _(i.translations.size).must_equal 4
  end

  it "must create the correct translations when assigned through nested_attributes" do
    i = ItemWithAttachedTranslations.new(
           :translations_attributes =>  [ { :name => "title", :locale => "fr", :value => "Nom" },
                                          { :name => "description", :locale => "fr", :value => "Description en français" },
                                          { :name => "title", :locale => "en", :value => "Name" },
                                          { :name => "description", :locale => "en", :value => "Description in English" } ])
    i.save
    id = i.id
    i = ItemWithAttachedTranslations.find(id)
    I18n.locale = :en
    result = "#{i.translate('title')}-#{i.translate('description')}"
    I18n.locale = :fr
    result = result + "-#{i.translate('title')}-#{i.translate('description')}"
    _(result).must_equal "Name-Description in English-Nom-Description en français"
    _(i.translations.size).must_equal 4
  end

end

