# -*- encoding : utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__),'test_helper'))

describe "ZLocalize Backend Test" do

  it "must translate 'Oui' into 'Yes' when locale is English" do
    ZLocalize.locale = :en
    ZLocalize.translate("Oui").must_equal "Yes"
  end

  it "must translate 'Yes' into 'Oui' when locale is French" do
    ZLocalize.locale = :fr
    ZLocalize.translate("Yes").must_equal "Oui"
  end

  it "must pluralize correctly" do
    ZLocalize.locale = :en
    ZLocalize.pluralize(["No messages", "One message", "{{count}} messages"],0).must_equal "No messages"
    ZLocalize.pluralize(["No messages", "One message", "{{count}} messages"],1).must_equal "One message"
  end

  it "must interpolate the value of count when pluralizing" do
    ZLocalize.locale = :en
    ZLocalize.pluralize(["No messages", "One message", "{{count}} messages"],43).must_equal "43 messages"
  end

  it "must not interpolate a value when it is escaped" do
    ZLocalize.interpolate(:en, "file {{file}} opened by \\{{user}}", { :file => 'test.txt', :user => 'Mr. X'}).must_equal "file test.txt opened by {{user}}"
  end

  it "must remove scope portion from translations" do
    ZLocalize.translate("my_scope::Real String").must_equal "Real String"
  end

  it "must not remove scoped translations when they are escaped" do
    ZLocalize.translate("my_scope\\::Real String").must_equal "my_scope::Real String"
  end

  it "must raise an ArgumentError when a value to be interpolated is missing" do
    begin
      ZLocalize.interpolate :en, "file {{file}} is nowhere to be found"
    rescue Exception => e
      e.must_be_instance_of(ArgumentError)
    end
  end

  it "must titleize using the proc defined for the current locale" do
    ZLocalize.titleize(:en, "this is meant to be titleized").must_equal "This Is Meant To Be Titleized"
    ZLocalize.titleize(:fr, "je suis un grand titre").must_equal "Je suis un grand titre"
  end

  it "must convert float representations according to current locale" do
    ZLocalize.convert_float(:fr, "2 000,234").must_equal "2000.234"
    ZLocalize.convert_float(:en, "2,000.234").must_equal "2000.234"
  end

end
