rails_version = '5.2'

Gem::Specification.new do |s|
  s.name        = 'zlocalize'
  s.version     = '6.0.8'

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ['Charles Bedard', 'Stephane Volet']
  s.email = ['zzeligg@gmail.com', 'steph@zboing.ca']
  s.date = '2024-03-06'
  s.license = 'MIT'
  s.homepage = 'https://github.com/zzeligg/zlocalize'
  s.summary = 'Translation engine for Rails applications'
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.files = Dir['CHANGELOG', 'README.rdoc', 'lib/**/*']

  if s.respond_to? :specification_version then
    s.specification_version = 4
    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      # https://github.com/rails/rails
      s.add_runtime_dependency('activerecord',  ">= #{rails_version}")
      s.add_runtime_dependency('activesupport', ">= #{rails_version}")
      s.add_runtime_dependency('actionpack',    ">= #{rails_version}")
      s.add_runtime_dependency('i18n',          [">= 0.7", "< 2"])
      # https://github.com/whitequark/parser
      s.add_runtime_dependency('parser',        ">= 2.7")
    else
      s.add_dependency('activerecord',  ">= #{rails_version}")
      s.add_dependency('activesupport', ">= #{rails_version}")
      s.add_dependency('actionpack',    "=> #{rails_version}")
      s.add_dependency('i18n',          [">= 0.7", "< 2"])
      s.add_dependency('parser',        ">= 2.7")
    end
  else
    s.add_dependency('activerecord',  ">= #{rails_version}")
    s.add_dependency('activesupport', ">= #{rails_version}")
    s.add_dependency('actionpack',    ">= #{rails_version}")
    s.add_dependency('i18n',          [">= 0.7", "< 2"])
    s.add_dependency('parser',        ">= 2.7")
  end

end
