rails_version = '6.0'

Gem::Specification.new do |s|
  s.name        = 'zlocalize'
  s.version     = '6.0.0'

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ['Charles Bedard', 'Stephane Volet']
  s.email = ['zzeligg@gmail.com', 'steph@zboing.ca']
  s.date = '2020-07-09'
  s.summary = 'Translation engine for Rails applications'
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.files = Dir['CHANGELOG', 'README.rdoc', 'lib/**/*']

  if s.respond_to? :specification_version then
    s.specification_version = 4
    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency('activerecord',  ">= #{rails_version}")
      s.add_runtime_dependency('activesupport', ">= #{rails_version}")
      s.add_runtime_dependency('actionpack',    ">= #{rails_version}")
      s.add_runtime_dependency('i18n',          ">= 1.7.0")
      s.add_runtime_dependency('parser',        ">= 2.7.1")
    else
      s.add_dependency('activerecord',  ">= #{rails_version}")
      s.add_dependency('activesupport', ">= #{rails_version}")
      s.add_dependency('actionpack',    ">= #{rails_version}")
      s.add_dependency('i18n',          ">= 1.7.0")
      s.add_dependency('parser',        ">= 2.7.1")
    end
  else
    s.add_dependency('activerecord',  ">= #{rails_version}")
    s.add_dependency('activesupport', ">= #{rails_version}")
    s.add_dependency('actionpack',    ">= #{rails_version}")
    s.add_dependency('i18n',          ">= 1.7.0")
    s.add_dependency('parser',        ">= 2.7.1")
  end

end
