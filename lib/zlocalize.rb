zlocalize_path = File.expand_path(File.dirname(__FILE__))
$:.unshift(zlocalize_path) if File.directory?(zlocalize_path) && !$:.include?(zlocalize_path)

require 'active_support/core_ext/string/output_safety'
require 'zlocalize/rails/railtie' # hook into Rails framework
require 'zlocalize/backend'

