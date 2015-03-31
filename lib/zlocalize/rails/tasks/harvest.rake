# -*- encoding : utf-8 -*-

require 'zlocalize/harvester'

namespace :zlocalize do

  desc "Collect all translatable strings (used in _('...') and n_('...') calls) in your Rails application\n\n" +
       "Usage: rake zlocalize:harvest\n" +
       "Options and their defaults are:\n\n" +
       "  output=FILE_PATH       Output file, relative to Rails.root (default: \'config/locales/app-strings.yml\')\n" +
       "  purge=true|false       Remove unused entries in the existing output file (if it exists). (default: false)\n" +
       "  clear=true|false       Clearing the existing translations in output file (if it exists). (default: false)\n" +
       "  silent=true|false      If true, do not report progress. (default: false)\n" +
       "  add_paths              Comma-separated list of path specs (relative to Rails.root) to harvest in addition to default paths"

  task :harvest => :environment do
    options = { :clear      => ['1','true'].include?(ENV['clear']),
                :purge      => ['1','true'].include?(ENV['purge']),
                :output     => ENV['output'].to_s.empty? ? 'config/locales/app-strings.yml' : ENV['output'],
                :add_paths  => ENV['add_paths'].to_s.empty? ? [] : ENV['add_paths'].split(','),
                :silent     => ['1','true'].include?(ENV['silent']) }

    h = ZLocalize::Harvester.new(File.expand_path(Rails.root), options)
    h.harvest
  end

  desc "Display which entries are not translated in given file\n\n" +
       "Usage: rake zlocalize:check_untranslated file=FILE_PATH\n\n" +
       "where FILE_PATH is the path to the YAML translation file relative to Rails.Root\n"
  task :check_untranslated => :environment do
    f = ZLocalize::TranslationFile.load(File.join(Rails.root,ENV['file']))
    num = 0
    f.entries.each_pair do |key,entry|
      if entry.translation.to_s == ""
         puts entry.to_yaml + "\n"
         num += 1
      end
    end
    puts "\n#{num} entries without a translation"
  end

end

