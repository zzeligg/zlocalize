# -*- encoding : utf-8 -*-

# ZLocalize configuration.

# ZLocalize is bound to use I18n.locale, I18n.default_locale, as to remain consistent
# with the locale used by the Rails framework itself
I18n.default_locale = :fr

# define_gettext_methods will add _ and n_ methods to the Object class (so that they are globally accessible)
# if you do not define the gettext methods, you will need to use ZLocalize.translate and ZLocalize.pluralize
ZLocalize.config.define_gettext_methods = true

# specify which Rails environments will reload the translation files on each request
ZLocalize.config.reload_per_request = { :development => false, :test => false,
                                        :production => false, :staging => false }

# specify which Rails environments will return the source string when a translation is not found
# when false. Defaults to false for all environments, meaning a missing translation will raise
# a ZLocalize::TranslationMissing error
ZLocalize.config.return_source_on_missing = { :development => true, :test => true,
                                              :production => true, :staging => true }

# +ZLocalize.config.locales+ is the configuration of locales supported by your application.
# each locale must be a Hash with the configuration values for that locale.
#
# You must define, for each language, the +plural_select+ Proc, which must return the
# index in the translation entry Array to use.
#
# +titleize+ handles the way a String is titleized (it defaults to the way ActiveSupport does it
# if it is not defined)
#
# :convert_float must be defined to handle input by users of your application so that those values
# are converted to the format used by your database (and Ruby).
#
# +:translations+ is the path of the YAML file containing the translations to be loaded for the locale.
# The default_locale doesn't need translation strings, since it is the base locale and it will
# simply return the string itself.

ZLocalize.config.locales = {
  :en => {
     :plural_select     => lambda { |n| n <= 0 ? 0 : (n > 1 ? 2 : 1) },
     :translations      => File.join(Rails.root,'config/locales/en.strings.yml'),
     :convert_float     => lambda { |s| s.to_s.gsub(',','') }
  },
#  :fr => {
#     :plural_select    => lambda { |n| n <= 0 ? 0 : (n > 1 ? 2 : 1) },
#     :translations     => File.join(Rails.root,'config/locales/fr.strings.yml'),
#     :titleize         => lambda { |s| s.capitalize.to_s },
#     :convert_float    => lambda { |s| s.to_s.gsub(' ','').gsub(',','.') }
#  }
}


