# -*- encoding : utf-8 -*-
require_relative './test_helper'

# Specs for the gem's declared dependency floors.
#
# The gem parses source with Prism (bundled with Ruby >= 3.4) and targets a
# supported Rails line. These specs pin that contract so a future edit cannot
# silently widen it back to a combination that cannot be installed.

class GemspecRubyVersionTest < Minitest::Test
  def setup
    @spec = Gem::Specification.load(File.expand_path('../../zlocalize.gemspec', __FILE__))
  end

  def test_requires_ruby_3_4_or_newer
    assert_equal true, @spec.required_ruby_version.satisfied_by?(Gem::Version.new('3.4.0')),
      'Ruby 3.4 is the oldest version bundling a usable Prism'
  end

  def test_rejects_ruby_older_than_3_4
    assert_equal false, @spec.required_ruby_version.satisfied_by?(Gem::Version.new('3.3.7')),
      'Ruby 3.3 must be rejected: no Prism in stdlib, and `parser` has no Ruby 4 target'
  end
end

class GemspecParserDependencyTest < Minitest::Test
  def setup
    @spec = Gem::Specification.load(File.expand_path('../../zlocalize.gemspec', __FILE__))
    @runtime = @spec.runtime_dependencies.map(&:name)
  end

  def test_declares_prism_as_the_parsing_backend
    prism = @spec.runtime_dependencies.find { |dep| dep.name == 'prism' }
    refute_nil prism
    assert prism.requirement.satisfied_by?(Gem::Version.new('1.2.0')),
      'must accept Prism 1.2, the version floor declared in the gemspec'
  end

  def test_does_not_depend_on_the_parser_gem
    refute_includes @runtime, 'parser',
      '`parser` has no Ruby 4 target; the harvester uses Prism instead'
  end
end

class GemspecRailsDependencyTest < Minitest::Test
  def setup
    @spec = Gem::Specification.load(File.expand_path('../../zlocalize.gemspec', __FILE__))
    @rails_deps = @spec.runtime_dependencies.select do |dep|
      %w[activerecord activesupport actionpack].include?(dep.name)
    end
  end

  def test_declares_all_three_rails_components
    assert_equal %w[activerecord activesupport actionpack].sort, @rails_deps.map(&:name).sort
  end

  def test_rails_floor_allows_rails_7_1
    @rails_deps.each do |dep|
      assert dep.requirement.satisfied_by?(Gem::Version.new('7.1.0')),
        "#{dep.name} must accept Rails 7.1 (declared minimum)"
    end
  end

  def test_rails_floor_rejects_rails_7_0
    @rails_deps.each do |dep|
      refute dep.requirement.satisfied_by?(Gem::Version.new('7.0.0')),
        "#{dep.name} must reject Rails 7.0 (below declared minimum)"
    end
  end

  def test_rails_floor_allows_rails_8_1
    @rails_deps.each do |dep|
      assert_equal true, dep.requirement.satisfied_by?(Gem::Version.new('8.1.0')),
        "#{dep.name} must accept Rails 8.1"
    end
  end

  def test_rails_floor_rejects_unsupported_rails_5_2
    @rails_deps.each do |dep|
      assert_equal false, dep.requirement.satisfied_by?(Gem::Version.new('5.2.0')),
        "#{dep.name} must reject Rails 5.2 (EOL, untestable)"
    end
  end
end
