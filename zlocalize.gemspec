# Oldest supported Rails line. Rails 5.2/6.x are EOL and are not exercised by the
# test suite, so they are no longer declared as installable.
rails_version = '7.1'

Gem::Specification.new do |s|
  s.name        = 'zlocalize'
  s.version     = '7.0.0'

  s.require_paths = ["lib"]
  s.authors = ['Charles Bedard', 'Stephane Volet']
  s.email = ['zzeligg@gmail.com', 'steph@zboing.ca']
  s.license = 'MIT'
  s.homepage = 'https://github.com/zzeligg/zlocalize'
  s.summary = 'Translation engine for Rails applications'

  # Ruby 3.4 is the oldest release bundling a usable Prism, which the harvester
  # needs to parse application source.
  s.required_ruby_version = Gem::Requirement.new(">= 3.4.0".freeze)

  s.files = Dir['CHANGELOG', 'README.md', 'MIT-LICENSE', 'lib/**/*']

  # https://github.com/rails/rails
  s.add_runtime_dependency('activerecord',  ">= #{rails_version}")
  s.add_runtime_dependency('activesupport', ">= #{rails_version}")
  s.add_runtime_dependency('actionpack',    ">= #{rails_version}")
  s.add_runtime_dependency('i18n',          [">= 0.7", "< 2"])
  # Parsing backend for the harvester. Ships in Ruby's standard library from 3.4
  # onwards; declared explicitly so it resolves on installs where it was removed
  # from the default set.
  s.add_runtime_dependency('prism',         ">= 1.2")
end
