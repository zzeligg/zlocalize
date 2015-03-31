# -*- encoding : utf-8 -*-

require 'rails/generators/base'

# module here is deliberately named Zlocalize (as opposed to ZLocalize), for consistency
# between the namespacing of rake tasks and rails generators
 module Zlocalize
    module Generators
      class InitializerGenerator < Rails::Generators::Base

        desc "Create ZLocalize initializer for your Rails application"

        source_root File.join(File.dirname(__FILE__),'templates')

        def create_initializer_file
          template "initializer_template.rb", "config/initializers/zlocalize.rb"
        end

      end
   end
end
