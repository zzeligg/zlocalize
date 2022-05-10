# ZLocalize - A translation engine for Rails 6+ applications

`ZLocalize` provides string translation through YAML-defined dictionaries.

What it does:

 * It uses strings in the source code as keys for lookups with interpolation
   of values.
 * It features a harvester rake task which scans the application source code
   (controllers, models, helpers and views) and to extract all the strings used
   in calls to translation methods.
 * The harvester also *manages* the translation entries, e.g. each time it
   runs, it will update the translation dictionaries without destroying
   existing entries or creating duplicate entries.
 * Translation dictionaries are stored as YAML files, containing metadata (such
   as unique entry ID's and a list of references where an entry is used, much
   like gettext .po files).
 * Provides a simple way to manage used-generated content in multiple languages
   by including modules an ActiveRecord.
 * Provides conversion of locale-formatted decimal values assigned to
   ActiveRecord attributes by users (through forms, console, etc.).

What it does not do:

 * Localization of date/time or other regional-dependent data (except for
   input of decimal values). For localization, you must use `I18n#localize`.
 * Provide an interface to edit and manage translations. You have to edit the
   YAML files by hand.

Within a Rails application, `ZLocalize` does not replace the `I18n` backend. Its
operation is (almost) entirely independent from `I18n`. The only tie to `I18n`
is the internal use of the `I18n#locale` and `I18n#default_locale` methods to
get/set its own active and default locales. Setting the active locale through
`ZLocalize` will set `I18n`'s locale and vice-versa.

Other than that, `ZLocalize` keeps its translation data isolated from the
`I18n` translation data.

The reason for this architecture is that the Rails framework itself contains a
finite set of strings, and as such `I18n` is already doing a fine job with
translation and localization of the framework internal strings and helpers,
using a hierarchical data store with Ruby symbols as keys.

One of the main reasons `ZLocalize` was created was to avoid having to deal
with symbols as keys while developing. It is much easier and straightforward
to start coding your application using a base locale, and then run the
harvester to collect all the strings used in the translation calls throughout
the source code.

## Requirements

  * Ruby 2.4 or later
  * Rails 6.0 or later

If you really must use this gem with a previous version of Ruby (< 2.0) or Rails (< 6.0),
install [ZLocalize 4.2.3](https://github.com/zzeligg/zlocalize/releases/tag/4.2.3).

## Installation

Add to your Gemfile:

    gem 'zlocalize'

and run +bundle install+

## Basic configuration

1. Create an initializer:

        bin/rails generate zlocalize:initializer

   This will create `config/initializers/zlocalize.rb` with some default
   configuration values.

   You can configure I18n and ZLocalize in each their own initializer files,
   or you can configure both in the same initializer.

   First, set the default locale:

        I18n.default_locale = :en

   Calling `I18n.default_locale` and `I18n.locale` is the same as calling
   `ZLocalize.default_locale` and `ZLocalize.locale`. The two are bound together.

2. Edit the `ZLocalize.config.locales` structure, by specifying a Hash for
   each locale you want to support. Each locale definition is a key/value pair.
   For example, the French locale definition could be:

        ZLocalize.config.locales = {
          :fr => {
            :plural_select    => -> (n) { n <= 0 ? 0 : (n > 1 ? 2 : 1) },
            :translations     => File.join(Rails.root,'config/translations/fr.strings.yml'),
            :titleize         => -> (s) { s.capitalize.to_s },
            :convert_float    => -> (s) { s.to_s.gsub(' ','').gsub(',','.') }
          }
        }

   * `:plural_select` is a proc evaluating the value of `n` for
     translation of plural strings (in calls to `ZLocalize#pluralize` or `n_`). It returns
     the index of the Array element to use as the translation for plural
     expressions.

   * `:translations` is an Array (or a single entry) of file names where the
     translations are stored.

   * `:titleize` is a proc to be used instead of ActiveSupport's `titleize`
     helper. Call `ZLocalize.titleize` instead of the builtin titleize (helper or
     `ActiveSupport::Inflector` method) in your application.

   * `:convert_float` is a proc to be used to convert ActiveRecord
     attributes containing decimal values. For example, in French, if the String
     `"1 234,23"` is assigned to a AR instance, it will be converted to `"1234.23"`
     so that Rails can then correctly convert it to `BigDecimal` internally.

   Note that you can also call `ZLocalize#convert_float` anywhere in your
   application.

3. Set the other configuration values:

  * `define_gettext_methods` : define `_()` and `n_()` (on `Object` class).
    Defaults to `true`. If you do not define the gettext methods, you will
    need to call `ZLocalize.translate` and `ZLocalize.pluralize` in your
    application.

  * `return_source_on_missing`: Hash with a key/value pair for each of your
    application environments. This indicates if missing translations in a
    given locale should raise a `ZLocalize::MissingTranslationDataError`
    exception. Defaults to `{ :development => true, :test => false,
    :production => false, :staging => false }`

  * `harvest_paths` : Array of path patterns (same as `Dir.glob`) relative to
    `Rails.root` that the ZLocalizer Harvester (see Harvester section below) will
    scan to collect all calls to `_()`, `n_()`, `ZLocalize.translate` and
    `ZLocalize.pluralize`. Defaults to
    `["app/channels/**/*.rb", "app/controllers/**/*.rb", "app/helpers/**/*.rb",
      "app/models/**/*.rb", "app/views/**/*.erb", "app/mailers/**/*.rb",
      "app/jobs/**/*.rb", "lib/**/*.rb" ]`


## In your application (Controllers, Helpers, Views, Models, etc.)

The idea is to simply start coding your application without thinking too much
about how to translate it. The only thing to worry about is wrapping any String
you will eventually want translated in a call to `_()` or `n_()` (or
`ZLocalize.translate` and `ZLocalize.pluralize`). Make sure you use parenthesis
for the parameter list to those methods (see Harvester section below for an
explanation).

For example, in a view:

    <%= _("Dear user") %>
    <%= n_(["No messages","One message", "{{count}} messages"], @user.messages.count) %>

Or in a controller:

    def create
      @post = Post.new(params[:post])
      if @post.save
        flash[:notice] = _("Your post has been added.")
        redirect_to [@post] and return
      else
        flash[:error] = _("There was an error adding your post")
      end
    end

There are 2 methods to translate content:

  * `ZLocalize.translate(key, options = {})` (and its gettext-style alias `_(key, options = {})`).
    This method looks up the String `key` with the following `options`:

      * `:locale`  : Lookup key in this locale. Defaults to `I18n.current_locale`.
      * `:default` : Return this String if key is not found.
      * `:return_source_on_missing` : Override the global `ZLocalize.config.return_source_on_missing` value.

    Any other option key passed is meant to be an interpolated named value. See Interpolation section below.

  * `ZLocalize.pluralize(key, count, options = {})` (and its gettext-style alias `n_(key, count, options = {})`).
    This methods looks up the Array `key` (which is an Array of String), and computes the index of the String to
    return based on the value of `count`. The index is computed using the `:plural_select`  Proc from
    `ZLocalize.config` (see Basic Configuration section above).

    The `options` are the same as the `translate`  method. Also, the `count` parameter is also automatically
    treated as a value to be interpolated (when `{{count}}` token is present in translation string).


## Interpolation

ZLocalize supports interpolation of values in source strings. Simply enclose
the values in double curly braces (`{{` and `}}`), and pass the actual values
in a Hash as the 2nd parameter to `ZLocalize.translate` and
`ZLocalize.pluralize`. For example:

    <%= _("Hello, {{username}}! How are you {{moment}}?",
            :username => @user.name,
            :moment => Time.now.hour > 18 ? _("tonight") : _("today") ) %>

If you need to output actual double curly braces, simply double-escape them:

    <%= _("Hello, \\{{username}}") %>

The above will return "Hello, {{username}}" without interpolation of
`{{username}}`.

## Namespacing Source Strings

It is possible to namespace (to give a scope to) a source string by simply
prefixing it with a name that ends with `::` . The namespace is used
when looking up the key in the current locale, but the prefix will always be
stripped in any output (even in the default locale).

Let's say your default locale is 'en':

    <%= _('btn::Edit') %>

The above returns "Edit" if the current locale is the base locale (en in this
case), and will lookup `"btn::Edit"` (e.g. including namespace) for all other
locales and return the corresponding translation. The translation may include a
scope, but it will be removed too.

The idea behind such scopes is that some languages have different spelling or
even words for a given word in another locale. For example, "Update" in English
can be used both as a noun and a verb. But it is not always the case in other
languages. By adding scopes such as `"btn::Update"` or `"title::Update"`, we
infer context to the string, so other languages would translate differently
depending on the context (scope). And in the base locale, only the part
after `::` would be shown (the scope would be stripped).

Should you need to output the scope delimiter `'::'` as is, escape it with a
backslash:

    <%= _("MyWebSite.com\\::HomePage") %>

The above will lookup `"MyWebSite.com\\::HomePage"`, but will not treat it as a
namespace prefix and will return the string with only the backslash stripped
(i.e. `"MyWebSite.com::HomePage"`).

## Harvester

Once you're ready to translate any work you've done:

    bin/rake zlocalize:harvest output=config/translations/fr.strings.yml

The harvester will scan your application (models, controllers, helpers, views
and any other path you might add). This will create a YAML file containing a
list of entries corresponding to all the strings used in the calls to
`_()` and `n_()` in your source code.

However, you have complete control over the location of your `ZLocalize`
translation files and can store them in any subdirectory of your Rails
application. See Basic Configuration section above.

Use `rake -D zlocalize:harvest` for a list of options.

#### HARVESTER LIMITATIONS

The parser used by the harvester module does have some limitations:

1. You *must* use parenthesis in the calls to `_()` and `n_()` (or
   `ZLocalize.translate` and `ZLocalize.pluralize`). While the Ruby language
   allows to omit parenthesis for method parameters, the Harvester parser does
   require them. The rule is simple: the parameter list to a translation
   method (and the parameters of any nested calls) must use parenthesis.

   This will not be harvested:

        _ "Hello"

        _ "Hello, {{name}}", :name => get_user_name @user

   But this will:

        _("Hello")

        _("Hello, {{name}}", :name => get_user_name(@user))


2. Translation calls inside interpolated double-quoted strings are not
   supported.

   While you can do something like:

        "This is #{_('embedded')} in a string"

   The Harvester parser will not detect the call. Avoid doing so.

## Translation file format

Entries in the YAML file have the following format:

    entry_00001:
      id: 1
      plural: false
      ignore: false
      references:
        - /app/views/users/show.html.erb:12
      source: "Dear user"
      translation: "Cher utilisateur"

    entry_00002:
      id: 2
      plural: true
      ignore: false
      references:
        - /app/views/users/show.html.erb:21
      source:
        - "No messages"
        - "One message"
        - "{{count}} messages"
      translation:
        - "Aucun message"
        - "Un message"
        - "{{count}} messages"

Note that for plural entries, the source is the Array of strings passed to
`n_()` (or `ZLocalize.pluralize()` ) in the source file. It can have any number
of elements, as required by your base locale. The translation is also an Array,
and it too can have any number of elements as required by the target locale.
It is up to the `:plural_selector` proc to compute the correct index to use
in the translation array.

## Updating translations when the application changes

Simply run `rake zlocalize:harvest` again, specifying as `output` the file that
already contains for the target language.

The Harvester will scan the source code and add/remove/modify the references to
all strings already present (if a string is not used anymore, it will be removed
only if you also add the `purge=true` parameter). It will of course also add any
missing string to the existing translation file.

## Translation of user-generated content (ActiveRecord)

Any ActiveRecord model can be made to support multiple languages for its
attributes. `ZLocalize` provides 2 mechanisms to achieve this:

### 1. Attached Translations

This method stores the translation of values in a separate model (judiciously)
called `Translation`.

Any model can have multiple translated values in multiple locales attached to
it. These values essentially become attributes of the model.

To use attached translations for a given model, declare `has_translations` for
that model. For example:

    class Page < ActiveRecord::Base
      ...
      has_translations
      ...
      validates :title, translation: { required_locales: [:fr, :en] }
      # `required_locales` can be a Symbol, in which case it refers to a method on the instance (no parameters)
      # that will be called when the validation is performed.
      # It can also be a Proc or lambda to be called, with (record, attribute, value) as parameters
      # validates :title, translation: { required_locales: :get_required_locales }
      # validates :title, translation: { required_locales: -> (record, attribute, value) { [:es, :fr] } }
      ...
      # return an Array of locale identifiers
      def get_required_locales
        [ :de, :en ]
      end
    end

From then on, any instance of Page will have the following methods:

  * `#translate(attr_name,locale = nil)`
  * `#add_translation(attr_name,locale,value)`
  * `#insert_translations(locales = {})`

So, a typical use with our example would be:

In the controller:

    def create
      @page = Page.new(params[:page])
      @page.add_translation('title',:fr,'Mon titre')
      @page.save
    end

And in a view (where the current locale is +:fr+):

    <h3><%= @page.translate(title) %></h3>   # => "Mon titre"

If you have some kind of administration interface, you can also mass-assign the
translations for a number of attributes and locales with the `insert_translations`
method.

`#insert_translations` accepts a Hash containing the translations for multiple
columns and locales. The Hash must have the locales as keys and its value is
another Hash of name-value pairs. As in:

    @article.insert_translations(
      { 'en' => { 'title'    => "What's new this week",
                  'synopsis' => "Learn what has happened this week"},
        'fr' => { 'title'    => "Quoi de neuf cette semaine",
                  'synopsis' => "Tout sur ce qui s'est passé cette semaine" }
    })

Alternatively, you can use ActiveRecord's builtin `accepts_nested_attributes_for`
mechanism to mass-assign translations:

    class Article < ActiveRecord::Base
      has_translations
      accepts_nested_attributes_for :translations, :allow_destroy => true
      ...
    end

And use `form.fields_for :translations` inside a view to have the translations
assigned directly...

The Translation model is loaded by `ZLocalize` itself, whenever a model
declares `has_translations`. The only thing missing is the translations table,
which you can generate with:

    rails generate zlocalize:translations_migration

And run `rake db:migrate`.

Attached translations are very flexible, because the values are not stored in
the model itself (as opposed to translated columns, explained in the next
section below). This allows to easily add new locales with minimal changes
to the models that use them. All this at the cost of having an association with
the `Translation` model.

### Validation of attached translations

`ZLocalize` also adds a Validator to ActiveRecord::Base, to check the presence
of attached validations:

    class Page < ActiveRecord::Base

      has_translations
      validates_translation_of :content, :required_locales => [:fr, :en]
      # or #
      validates :content, :translation => { :required_locales => [:fr, :en] }
      # or #
      validates :content, :translation => { :required_locales => :get_required_locales }
      ...

      def get_required_locales
        [:es, :en]
      end

    end

This will generate an error message for each missing translation:

    p = @page.create

    p.errors[:content]    # => ["content is missing its translation in fr, en"]

The `required_locales` option can also be a Proc/lambda:

    validates_translation_of [:title, :content], :required_locales => -> (record,attribute,value) {
                                                    if attribute == 'content'
                                                      [:fr,:en]
                                                    else
                                                      [:fr]
                                                    end }

The other standard validation options, such as `:message`, `:on`, `:if` and
`:unless` are also supported. `:message` defaults to `:missing_translations` and this value should be
added to the I18n translations for Rails, with the other ActiveRecord validation messages:

      en:
        errors:
          messages: &errors_messages
            inclusion: "n'est pas inclus(e) dans la liste"
            exclusion: "n'est pas disponible"
            ...
            missing_translations: "doit être traduit en %{locales}"


and the `%{locales}` token will be interpolated to the actual missing locales.

### 2. Translated columns

This second attribute translation mechanism works a bit differently. It is
basically a wrapper around column names, allowing to use different attribute
values for each locale.

First, you need to create the columns in the model table. You need one column
for each attribute and locale pair. For example, a `title` attribute with
values in French and English would require 2 columns:

    create_table 'pages' do |t|
      t.string :title_en
      t.string :title_fr
      ...
    end

In your model:

    class Page < ActiveRecord::Base
      translates_columns [:title]
    end

Then whenever you want to access the value of +title+ in the current locale:

    <%= @page.title %>

The wrapper method can take a Hash of options:

  * `:locale` to force a given locale
  * `:fetch_default` (`true|false`) to retrieve the the value of the attribute
    in the `default_locale`. Defaults to `true`

For example:

    <%= @page.title(:locale => :fr, :fetch_default => false) %>

This will automatically call the wrapper method to read the value of the column
in the `:fr` locale (the value of `title_fr`). If `title_fr` is nil,
then the value in the `default_locale` will not be fetched and `nil` will be
returned. If `fetch_default` is `true`, then the value of `title_en` (given
that the `default_locale` is `:en`) would be fetched.

Translated columns are more efficient in terms of fetching translated content,
because they are always part of the underlying table columns. If you know in
advance the exact locales you are going support in your application, and that
only 2-3 locales will be present, then having multiple columns for each
attribute is probably the way to go. If you have many locales and/or the
attributes to be translated are large (text columns and such), then maybe
Attached Translations would be a better strategy.

## Localized Decimal Attributes

`ZLocalize` provides a way to declare some ActiveRecord attributes as being
localized decimal values. This ensures the assignment of decimal values from
their string-based representation will not fail. For example, in French, the
decimal separator is a period ('.') and the thousands separator is a space.
Assigning the string `"1 234,56"` to a decimal attribute will cause the value
to become 1.0 (the `BigDecimal` class will parse the string, but stop at the
space).

To enable correct decimal attribute assignment for different locales, declare
the attributes as such:

    class Account < ActiveRecord::Base
      localize_decimal_attributes [:balance, :variation]
    end

Then, you can safely assign a string representing a decimal value in the
current locale:

    Zlocalize.locale = :fr
    @account.balance = "8 765,43"
    => 8765.43

Conversion from a locale-specific decimal value to `BigDecimal` is done by
the `:convert_float` Proc declared in `ZLocalize.locales` (in the
initializer). For example, in English:

      ZLocalize.config.locales = {
        :en => {
           :plural_select     => -> (n) { n <= 0 ? 0 : (n > 1 ? 2 : 1) },
           :convert_float     => -> (s) { s.to_s.gsub(',','') }
        }
        ...
      }

## License

`ZLocalize` is released under the MIT license.

## Support

Source code, documentation, bug reports, feature requests or anything else is
at

  * http://github.com/zzeligg/zlocalize

## Credits

This plugin is based on original work by Thomas Fuchs (A Rails 1.X plugin named
Localization), but it has been extended in many ways to make it answer our needs.

Many thanks to Stephane Volet (https://github.com/schmlblk) for his contributions and ideas
to this gem.
