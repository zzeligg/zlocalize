# -*- encoding : utf-8 -*-

class CreateZLocalizeTranslationsTable < ActiveRecord::Migration
   def self.up
     create_table :translations do |t|
       t.string :translated_type
       t.integer :translated_id
       t.string :name
       t.string :locale
       t.text :value

       t.timestamps
    end
    add_index 'translations', ['translated_type','translated_id'], :name => 'index_on_translated'
    add_index 'translations', ['name','locale'], :name => 'index_for_lookup'
  end

  def self.down
    drop_table :translations
  end
end
