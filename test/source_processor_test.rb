# -*- encoding : utf-8 -*-
require_relative './test_helper'
require 'zlocalize/source_processor'
require 'tempfile'
require 'tmpdir'

# Specs for the source harvester's parser backend (Prism).
#
# A translation call is recognized when it is a bare call to `_` / `n_`, or a call
# on the `ZLocalize` constant to `translate` / `pluralize`. Each recognized call
# yields one entry carrying: the source string(s), whether it is plural, and a
# "relative/path:line" reference to where it occurs.

class SourceProcessorRubyFileTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('zlocalize-src')
    # line numbers matter: see the source below
    @source = <<~RUBY
      class Thing
        def plain
          _("Hello world")
        end

        def counted
          n_(["No items", "One item", "{{count}} items"], count)
        end

        def qualified
          ZLocalize.translate("Qualified string")
        end

        def qualified_plural
          ZLocalize.pluralize(["None", "One", "{{count}}"], n)
        end

        def not_a_translation
          other("Ignored string")
        end
      end
    RUBY
    write_file('thing.rb', @source)
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def process(name = 'thing.rb', root = @dir)
    ZLocalize::SourceProcessor.new(File.join(@dir, name), root, name.end_with?('.erb'))
  end

  def write_file(name, content)
    File.write(File.join(@dir, name), content)
  end

  def entry_for(source)
    entries = process.translation_entries
    assert entries.key?(source), "expected an entry for #{source.inspect}, got: #{entries.keys.inspect}"
    entries[source]
  end

  def test_extracts_bare_underscore_call_as_singular_entry
    entry = entry_for("Hello world")
    assert_same false, entry.plural
    assert_equal "Hello world", entry.source
  end

  def test_extracts_n_underscore_call_as_plural_entry_with_all_forms
    entry = entry_for(["No items", "One item", "{{count}} items"])
    assert_same true, entry.plural
    assert_equal ["No items", "One item", "{{count}} items"], entry.source
  end

  def test_extracts_zlocalize_translate_call_as_singular_entry
    entry = entry_for("Qualified string")
    assert_same false, entry.plural
    assert_equal "Qualified string", entry.source
  end

  def test_extracts_zlocalize_pluralize_call_as_plural_entry_with_all_forms
    entry = entry_for(["None", "One", "{{count}}"])
    assert_same true, entry.plural
    assert_equal ["None", "One", "{{count}}"], entry.source
  end

  def test_ignores_calls_to_other_methods
    entries = process.translation_entries
    refute entries.key?("Ignored string"),
      "a call to a non-translation method must not produce an entry"
  end

  def test_ignores_translation_named_methods_on_other_receivers
    write_file('wrong_receiver.rb', <<~RUBY)
      Other.translate("Other.translate")
      ZLocalize.other("ZLocalize.other")
      helper._("helper underscore")
    RUBY
    entries = process('wrong_receiver.rb').translation_entries
    assert_empty entries, "recognized method names on wrong receivers must be ignored"
  end

  def test_reference_records_relative_path_and_line_of_call
    # `_()` is on line 3, `n_()` on line 7, `translate` on line 11, `pluralize` on line 15
    assert_equal ["thing.rb:3"], entry_for("Hello world").references
    assert_equal ["thing.rb:7"], entry_for(["No items", "One item", "{{count}} items"]).references
    assert_equal ["thing.rb:11"], entry_for("Qualified string").references
    assert_equal ["thing.rb:15"], entry_for(["None", "One", "{{count}}"]).references
  end

  def test_reference_is_relative_to_root_not_absolute
    nested = File.join(@dir, 'app', 'models')
    FileUtils.mkdir_p(nested)
    File.write(File.join(nested, 'widget.rb'), %Q{_("Nested string")\n})
    entries = ZLocalize::SourceProcessor.new(File.join(nested, 'widget.rb'), @dir).translation_entries
    assert_equal ["app/models/widget.rb:1"], entries["Nested string"].references
  end

  def test_same_string_used_twice_collects_both_references
    write_file('twice.rb', %Q{_("Repeated")\nx = 1\n_("Repeated")\n})
    entries = ZLocalize::SourceProcessor.new(File.join(@dir, 'twice.rb'), @dir).translation_entries
    assert_equal ["twice.rb:1", "twice.rb:3"], entries["Repeated"].references
  end

  def test_rejects_interpolated_string_with_argument_error_naming_the_file
    # Only literal strings are harvestable; interpolated content cannot become a
    # translation key.
    write_file('interp.rb', %q{_("Hello #{name}")} + "\n")
    err = assert_raises(ArgumentError) { process('interp.rb') }
    assert_includes err.message, 'interp.rb'
  end

  def test_rejects_interpolated_qualified_string_with_argument_error_naming_the_file
    write_file('qualified_interp.rb', %q{ZLocalize.translate("Hello #{name}")} + "\n")
    err = assert_raises(ArgumentError) { process('qualified_interp.rb') }
    assert_includes err.message, 'qualified_interp.rb'
  end

  def test_rejects_plural_forms_that_are_not_all_literals
    write_file('badplural.rb', %q{n_(["ok", "bad #{x}"], n)} + "\n")
    err = assert_raises(ArgumentError) { process('badplural.rb') }
    assert_includes err.message, 'badplural.rb'
  end

  def test_rejects_dynamic_singular_source_with_argument_error_naming_the_file
    write_file('dynamic.rb', %q{source = 'Hello'; _(source)} + "\n")
    err = assert_raises(ArgumentError) { process('dynamic.rb') }
    assert_includes err.message, 'dynamic.rb'
  end

  def test_rejects_plural_forms_containing_a_non_string_literal
    write_file('badplural.rb', "n_(['ok', 42], n)\n")
    err = assert_raises(ArgumentError) { process('badplural.rb') }
    assert_includes err.message, 'badplural.rb'
  end

  def test_extracts_nested_translation_call_in_additional_arg
    write_file('nested.rb', <<~RUBY)
      _("Outer", fallback: _("Inner"))
    RUBY
    entries = process('nested.rb').translation_entries
    assert entries.key?("Outer")
    assert entries.key?("Inner")
  end

  def test_raises_argument_error_naming_the_file_on_syntax_error
    write_file('broken.rb', %Q{def unclosed\n  _("string"\n})
    err = assert_raises(ArgumentError) { process('broken.rb') }
    assert_includes err.message, 'broken.rb'
  end
end

class SourceProcessorErbFileTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('zlocalize-erb')
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def test_extracts_translation_calls_from_erb_template
    erb = <<~ERB
      <h1><%= _("Page title") %></h1>
      <p><%= n_(["No posts", "One post", "{{count}} posts"], @posts.size) %></p>
      <p><%= ZLocalize.translate("Qualified in ERB") %></p>
    ERB
    path = File.join(@dir, 'page.html.erb')
    File.write(path, erb)
    entries = ZLocalize::SourceProcessor.new(path, @dir, true).translation_entries

    assert_equal "Page title", entries.fetch("Page title").source
    assert_same false, entries.fetch("Page title").plural
    assert_equal ["page.html.erb:1"], entries.fetch("Page title").references
    assert_equal ["No posts", "One post", "{{count}} posts"],
      entries.fetch(["No posts", "One post", "{{count}} posts"]).source
    assert_same true, entries.fetch(["No posts", "One post", "{{count}} posts"]).plural
    assert_equal ["page.html.erb:2"], entries.fetch(["No posts", "One post", "{{count}} posts"]).references
    assert_equal "Qualified in ERB", entries.fetch("Qualified in ERB").source
    assert_same false, entries.fetch("Qualified in ERB").plural
    assert_equal ["page.html.erb:3"], entries.fetch("Qualified in ERB").references
    assert_equal 3, entries.size
  end

  def test_extracts_translation_calls_from_erb_template_with_yield
    # Rails layouts use `yield` (bare and with a symbol argument). Erubi compiles
    # this to top-level `yield`, which Prism rejects unless wrapped in a method.
    erb = <<~ERB
      <html>
      <head><%= yield :head %></head>
      <body><%= yield %></body>
      <footer><%= _("Footer text") %></footer>
      </html>
    ERB
    path = File.join(@dir, 'layout.html.erb')
    File.write(path, erb)
    entries = ZLocalize::SourceProcessor.new(path, @dir, true).translation_entries

    assert_equal "Footer text", entries.fetch("Footer text").source
    assert_equal ["layout.html.erb:4"], entries.fetch("Footer text").references
  end

  def test_erb_reference_line_matches_the_template_line
    erb = "<p>nothing</p>\n<p>text</p>\n<p>text</p>\n<p><%= _(\"Later string\") %></p>\n"
    path = File.join(@dir, 'lines.html.erb')
    File.write(path, erb)
    entries = ZLocalize::SourceProcessor.new(path, @dir, true).translation_entries
    assert_equal ["lines.html.erb:4"], entries["Later string"].references
  end
end
