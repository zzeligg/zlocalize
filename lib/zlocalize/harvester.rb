# -*- encoding : utf-8 -*-

require 'rubygems'
require 'erb'
require File.join(File.dirname(__FILE__),'source_parser')
require File.join(File.dirname(__FILE__),'translation_file')

module ZLocalize

   INDENT_STEP = 3

   class HarvesterError < StandardError
   end

   # Harvester will parse and extract all calls to translation methods in "app/models/",
   # "app/controllers/" and "app/views/"
   class Harvester

     attr_accessor :rails_root

     DEFAULT_HARVEST_OPTIONS = { :models => true, :controllers => true,
                                 :views => true, :helpers => true,
                                 :output => 'config/locales/app-strings.yml',
                                 :overwrite_existing => false,
                                 :add_paths   => [],
                                 :silent => false,
                                 :purge => false }

     HARVEST_SECTIONS = { :models      => [ "app/models/**/*.rb" ],
                          :controllers => [ "app/controllers/**/*.rb" ],
                          :helpers     => [ "app/helpers/**/*.rb" ],
                          :views       => [ "app/views/**/*.erb", "app/views/**/*.rhtml" ],
                          :lib         => [ "lib/**/*.rb"]
                        }

     def initialize(rails_root, options = {})
        @rails_root = rails_root
        @options = DEFAULT_HARVEST_OPTIONS.merge(options)
     end

     def progress(msg)
        print msg unless @options[:silent]
     end

     def harvest_section(section,filespecs)
       progress("Harvesting localizable strings from #{section}:\n")
       filespecs.each do |spec|
         progress("#{spec}: ")
         Dir.glob(File.join(@rails_root,spec)) do |f|
           progress('.')
           collect_entries(f,@rails_root,is_erb?(f))
         end
         progress("\n")
       end
     end

     def is_erb?(filename)
       ['.erb','.rhtml'].include?(File.extname(filename))
     end

     def harvest
        @new_entries = TranslationEntryCollection.new
        HARVEST_SECTIONS.each_pair do |section,paths|
          harvest_section(section,paths)
          progress("\n")
        end
        if @options[:add_paths].is_a?(Array) && @options.size > 0
          harvest_section("additional paths",@options[:add_paths])
          progress("\n")
        end

        @translation_file = ZLocalize::TranslationFile.new
        unless @options[:overwrite_existing]
           progress("Merging existing translations from #{@options[:output]}...\n")
           begin
             @translation_file.load(File.join(@rails_root,@options[:output]))
           rescue
           end
        end

        @translation_file.entries.synchronize_with(@new_entries,@options[:purge])

        progress("Writing new translation file...\n")
        File.open(File.join(@rails_root,@options[:output]),"w") do |f|
           f.write(@translation_file.to_yaml)
        end

        progress("Done!\n\n")
     end

     def harvest_file(filename)
       @new_entries = TranslationEntryCollection.new
       collect_entries(filename,@rails_root,false)

       @translation_file = ZLocalize::TranslationFile.new
       # merge
       @translation_file.load(File.join(@rails_root,@options[:output]))
       @translation_file.entries.synchronize_with(@new_entries,@options[:purge])
       File.open(File.join(@rails_root,@options[:output]),"w") do |f|
          f.write(@translation_file.to_yaml)
       end
     end

     # collect entries in a source file
     def collect_entries(filename,root,is_erb = false)
        sp = ZLocalize::SourceParser.new(filename,root,is_erb)
        sp.parse
        sp.translation_entries.each do |key,te|
          if @new_entries[key]
             te.references.each do |ref|
                @new_entries[key].add_reference(ref)
             end
          else
            @new_entries[key] = te.dup
          end
        end
     end

   end

end # module Harvester


