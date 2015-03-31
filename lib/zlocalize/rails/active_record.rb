# -*- encoding : utf-8 -*-

require 'zlocalize/rails/attached_translations'
ActiveRecord::Base.send(:include, ZLocalize::Translatable::AttachedTranslations)

require 'zlocalize/rails/translated_columns'
ActiveRecord::Base.send(:include, ZLocalize::Translatable::TranslatedColumns)

require 'zlocalize/rails/decimal_attributes'
ActiveRecord::Base.send(:include, ZLocalize::Translatable::LocalizedDecimalAttributes)

