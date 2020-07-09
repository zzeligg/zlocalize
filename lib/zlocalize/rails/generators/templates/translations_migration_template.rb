class CreateTranslationsTable < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]

   def change
     create_table :translations do |t|
       t.string :translated_type
       t.integer :translated_id
       t.string :name
       t.string :locale
       t.text :value

       t.timestamps
    end
    add_index 'translations', ['translated_type','translated_id'], name: 'index_on_translated'
    add_index 'translations', ['name','locale'], name: 'index_for_lookup'
  end

end
