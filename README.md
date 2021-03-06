LolitaHasTranslations
======================

This is a fork of http://github.com/dmitry/has_translations with small changes.

1. The main difference is that the translations table holds only translations, but not the original data from default_locale, so:

    I18n.default_locale = :en
    I18n.locale = :lv
    
    a = Article.create :title => "Title in EN"
    a.title
    # returns blank, because current locale is LV and there is no translation in it
    => ""
    I18n.locale = :en
    a.title
    => "Title in EN"
    a.translations.create :title => "Title in LV", :locale => 'lv'
    I18n.locale = :lv
    a.title
    => "Title in LV"

2. When a "find" is executed and current language is not the same as default language then :translations are added to :includes
   to pre fetch all translations.

3. The "ModelNameTranslation" class is created for you automaticly with all validations for ranslated fields. Of course you can create it manualy for custom vlidations and other.

4. You dont have to create migration for the translation table, just add a line for every translated model in `db/seed.rb`

    TextPage.sync_translation_table!
    Blog::Article.sync_translation_table!

   And run `rake db:seed` and it will do it for you. It also updates the table if you add news columns in the `translations :name, :title .....` method.

HasTranslations v0.3.1
======================

This simple plugin creates translations for your model.
Uses delegation pattern: http://en.wikipedia.org/wiki/Delegation_pattern

Tested with ActiveRecord versions: 2.3.5, 2.3.9, 3.0.0 (to test with Rails 3 run `rake RAILS_VERSION=3.0`)

Installation
============

    gem install has_translations

or as a plugin

    script/plugin install git://github.com/dmitry/has_translations.git

Example
=======

For example you have Article model and you want to have title and text to be translated.

Create model named ArticleTranslation (Rule: [CamelCaseModelName]Translation)

Migration should have `locale` as a string with two letters and `belongs_to associative id`, like:

    class CreateArticleTranslations < ActiveRecord::Migration
      def self.up
        create_table :article_translations do |t|
          t.integer :article_id, :null => false
          t.string :locale, :null => false, :limit => 2
          t.string :title, :null => false
          t.text :text, :null => false
        end

        add_index :article_translations, [:article_id, :locale], :unique => true
      end

      def self.down
        drop_table :article_translations
      end
    end

Add to article model `translations :value1, :value2`:

    class Article < ActiveRecord::Base
      translations :title, :text
    end

And that's it. Now you can add your translations using:

    article = Article.create

    article.translations.create(:locale => 'en', :title => 'title', :text => 'text') # or ArticleTranslation.create(:article => article, :locale => 'en', :title => 'title', :text => 'text')
    article.translations.create(:locale => 'ru', :title => 'заголовок', :text => 'текст')
    article.reload # reload cached translations association array
    I18n.locale = :en
    article.text # text
    I18n.locale = :ru
    article.title # заголовок

You can use text filtering plugins, like acts_as_sanitiled and validations, and anything else that is available to the ActiveRecord:

    class ArticleTranslation < ActiveRecord::Base
      acts_as_sanitiled :title, :text

      validates_presence_of :title, :text
      validates_length_of :title, :maximum => 100
    end

Options:

* :fallback => true [default: false] - fallback 1) default locale; 2) first from translations;
* :reader => false [default: true] - add reader to the model object
* :writer => true [default: false] - add writer to the model object
* :nil => nil [default: ''] - if no model found by default returns empty string, you can set it for example to `nil` (no `lambda` supported)

It's better to use translations with `accepts_nested_attributes_for`:

    accepts_nested_attributes_for :translations

To create a form for this you can use `all_translations` method. It's have all
the locales that you have added using the `I18n.available_locales=` method.
If translation for one of the locale isn't exists, it will build it with :locale.
So an example which I used in the production (using `formtastic` gem):

    <% semantic_form_for [:admin, @article] do |f| %>
      <%= f.error_messages %>

      <% f.inputs :name => "Basic" do %>
        <% object.all_translations.values.each do |translation| %>
          <% f.semantic_fields_for :translations, translation do |ft| %>
            <%= ft.input :title, :label => "Title #{ft.object.locale.to_s.upcase}" %>
            <%= ft.input :text, :label => "Text #{ft.object.locale.to_s.upcase}" %>
            <%= ft.input :locale, :as => :hidden %>
          <% end %>
        <% end %>
      <% end %>
    <% end %>

Sometimes you have validations in the translation model, and if you want to skip
the translations that you don't want to add to the database, you can use
`:reject_if` option, which is available for the `accepts_nested_attributes_for`:

    accepts_nested_attributes_for :translations, :reject_if => lambda { |attrs| attrs['title'].blank? && attrs['text'].blank? }

named_scope `translated(locale)` - with that named_scope you can find only
those models that is translated only to specific locale. For example if you will
have 2 models, one is translated to english and the second one isn't, then it
`Article.translated(:en)` will find only first one.

PS
==

I suggest you to use latest i18n gem, include it in your rails 2 environment:

    config.gem 'i18n', :version => '0.4.1' # change version to the latest

TODO
====

* add installation description to readme
* model and migration generators
* caching
* write more examples: fallback feature
* write blog post about comparison and benefits of this plugin between another translation model plugins


Alternatives
============

I know three of them:

* [puret](http://github.com/jo/puret) - special for Rails 3 and almost the same as this project.
* [globalite2](http://github.com/joshmh/globalize2) - a lot of magic.
* [model_translations](http://github.com/janne/model_translations) - almost the same as this project, but more with more code in lib.
* [translatable_columns](http://github.com/iain/translatable_columns) - different approach: every column have own postfix "_#{locale}" in the same table (sometimes it could be fine).


Used in
=======

[noch.es](http://noch.es/), [eten.es](http://www.eten.es), [sem.ee](http://sem.ee/)


Copyright (c) 2009-2010 [Dmitry Polushkin], released under the MIT license
