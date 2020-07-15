require 'zlocalize'
require 'rails'
require 'active_record'
require 'sprockets/railtie'

module ZLocalize
  class Railtie < Rails::Railtie

    initializer "Zlocalize.load_translation_model" do
      require File.expand_path('./translation',File.dirname(__FILE__))
    end

    initializer "ZLocalize.load_active_record_extensions" do
      require File.expand_path('./active_record.rb',File.dirname(__FILE__))
    end

    rake_tasks do
      load File.expand_path('./tasks/harvest.rake',File.dirname(__FILE__))
    end

    generators do
      load File.expand_path('./generators/initializer.rb',File.dirname(__FILE__))
      load File.expand_path('./generators/translations_migration.rb',File.dirname(__FILE__))
    end

  end
end
