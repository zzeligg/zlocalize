# -*- encoding : utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__),'test_helper'))

describe "ZLocalize ActiveRecord with Translated Columns" do

  it "must return the attribute value in the current locale" do
    i = ItemWithTranslatedColumn.create(:description_en => "English description", :description_fr => "Description française")
    id = i.id
    i = ItemWithTranslatedColumn.find(id)
    ZLocalize.locale = :en
    i.description.must_equal "English description"
    ZLocalize.locale = :fr
    i.description.must_equal "Description française"
  end

  it "must return the attribute value in default locale when no value exists for current locale" do
    i = ItemWithTranslatedColumn.create(:description_en => "English description")
    id = i.id
    i = ItemWithTranslatedColumn.find(id)
    ZLocalize.locale = :fr
    i.description(:fetch_default => true).must_equal "English description"
    i.description(:fetch_default => false).must_be_nil
  end

end

describe "ZLocalize ActiveRecord Decimal Attributes" do

  it "must return the correct float value from another locale (French)" do
    ZLocalize.locale = :fr
    i = ItemWithTranslatedColumn.new(:amount => "1 234,567")
    i.amount.must_equal 1234.567
  end

  it "must return the correct float value from a formatted float in English" do
    ZLocalize.locale = :en
    i = ItemWithTranslatedColumn.new(:amount => "234,000.567")
    i.amount.must_equal 234000.567
  end

end

describe "ZLocalize ActiveRecord with Attached Translations" do

  it "must return translation of name in English on a new_record which calls #add_translation" do
    i = ItemWithAttachedTranslation.new
    i.add_translation('name','en',"English name")
    i.translate('name','en').must_equal "English name"
    i.translations.size.must_equal 1
  end

  it "must return translation of name in English on a saved record" do
    i = ItemWithAttachedTranslation.new
    i.add_translation('name','en','English name')
    i.save
    # verify that a Translation exists for our item
    v = i.translations.where(:locale => 'en', :name => 'name').first
    v.must_be_instance_of(Translation)
    if v.is_a?(Translation)
      v.value.must_equal "English name"
    end
  end

  it "must create the correct translations when assigned through insert_translations" do
    i = ItemWithAttachedTranslation.new
    i.insert_translations({ :fr => { :title => "Nom", :description => "Description en français" },
                            :en => { :title => "Name", :description => "Description in English" } })
    i.save
    id = i.id
    i = ItemWithAttachedTranslation.find(id)
    I18n.locale = :en
    result = "#{i.translate('title')}-#{i.translate('description')}"
    I18n.locale = :fr
    result = result + "-#{i.translate('title')}-#{i.translate('description')}"
    result.must_equal "Name-Description in English-Nom-Description en français"
    i.translations.size.must_equal 4
  end

  it "must create the correct translations when assigned through nested_attributes" do
    i = ItemWithAttachedTranslation.new(:translations_attributes =>  [
                   { :name => "title", :locale => "fr", :value => "Nom" },
                   { :name => "description", :locale => "fr", :value => "Description en français" },
                   { :name => "title", :locale => "en", :value => "Name" },
                   { :name => "description", :locale => "en", :value => "Description in English" } ])
    i.save
    id = i.id
    i = ItemWithAttachedTranslation.find(id)
    I18n.locale = :en
    result = "#{i.translate('title')}-#{i.translate('description')}"
    I18n.locale = :fr
    result = result + "-#{i.translate('title')}-#{i.translate('description')}"
    result.must_equal "Name-Description in English-Nom-Description en français"
    i.translations.size.must_equal 4
  end

  it "must return the attribute value in default locale when no value exists for current locale" do
    i = ItemWithAttachedTranslation.new(:translations_attributes =>  [
                   { :name => "title", :locale => "en", :value => "Name" },
                   { :name => "description", :locale => "en", :value => "Description in English" } ])
    i.save
    id = i.id
    i = ItemWithAttachedTranslation.find(id)
    i.translate('description', :fr, :fetch_default => true).must_equal "Description in English"
    i.translate('description', :fr, :fetch_default => false).must_be_nil
  end
end

describe "ZLocalize ActiveRecord with Serialized Translations" do

  it "must return the attribute value in the current locale" do
    i = ItemWithSerializedTranslation.new
    i.translated_attributes = { :en => { :description => "English description" }, :fr => { :description => "Description française" } }
    i.save
    id = i.id
    i = ItemWithSerializedTranslation.find(id)
    ZLocalize.locale = :en
    i.description.must_equal "English description"
    ZLocalize.locale = :fr
    i.description.must_equal "Description française"
  end

  it "must return the attribute value in default locale when no value exists for current locale" do
    i = ItemWithSerializedTranslation.new
    i.translated_attributes = { :en => { :description => "English description" } }
    i.save
    id = i.id
    i = ItemWithSerializedTranslation.find(id)
    ZLocalize.locale = :fr
    i.description(:fetch_default => true).must_equal "English description"
    i.description(:fetch_default => false).must_be_nil
  end

end

