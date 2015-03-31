# -*- encoding : utf-8 -*-

require 'rails/generators/base'
require 'rails/generators/migration'

# module here is deliberately named Zlocalize (as opposed to ZLocalize), for consistency
# between the namespacing of rake tasks and rails generators
module Zlocalize
    module Generators
      class TranslationsMigrationGenerator < Rails::Generators::Base
        include Rails::Generators::Migration

        desc "Generate the migration to create a `translations` table used by ZLocalize"

        source_root File.join(File.dirname(__FILE__),'templates')

        def self.next_migration_number(path)
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        end

        def create_migration_file
          migration_template 'translations_migration_template.rb', 'db/migrate/create_translations_table.rb'
        end

      end
   end
end
