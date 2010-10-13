# encoding: utf-8
require File.dirname(__FILE__) + '/test_helper.rb'

class HasTranslationsTest < Test::Unit::TestCase
  def setup
    setup_db
    
    [Article, ArticleTranslation, Team, TeamTranslation].each do |k|
      k.delete_all
    end
    I18n.locale = :ru
  end

  def teardown
    teardown_db
  end

  def test_schema_has_loaded_correctly
    [Article, ArticleTranslation, Team, TeamTranslation].each do |k|
      assert_equal [], k.all
    end
    assert_equal :ru, I18n.locale
  end

  def test_reader_text_for_a_given_locale
    article = Article.create!(:description => 'ru desc', :text => 'ru text')
    article.translations.create!(:locale => 'en', :description => 'en desc', :text => 'en text')
    assert_equal article.text, 'ru text'
    I18n.locale = :en
    assert_equal article.text, 'en text'
  end

  def test_writer_text_for_a_given_locale
    article = Article.create!
    article.text = 'text'
    assert_equal 0, article.translations.count
    article.save!
    assert_equal 1, article.translations.length
    assert_equal 1, article.translations.count
    I18n.locale = :en
    assert_equal '', article.text
    article.update_attributes!(:text => 'text')
    assert_equal 2, Article.first.translations.count
  end

  def test_translations_association_and_translations
    article = Article.create!
    assert_equal [], article.translations
    article_translation = ArticleTranslation.create!(:article => article, :locale => 'ru', :description => 'описание', :text => 'текст')
    assert_equal [], article.translations
    assert_equal [article_translation], article.reload.translations
    assert_equal 'текст', article.text
    I18n.locale = :en
    assert_equal '', article.text
    assert_equal article_translation, article.translation('ru')
    assert_equal article_translation, article.translation(:ru)
    assert article.destroy
    assert_equal [], ArticleTranslation.all
  end

  def test_translation_validations
    article_translation = ArticleTranslation.create(:description => 'description', :text => 'text')
    assert article_translation.errors[:locale].present?
    # TODO may be add :inverse_of to has_many and add presence validation for the belongs_to
  end

  def test_fallback_and_nil_options
    article = Article.create! :text => ''
    assert_equal '', article.text
    team = Team.create! :text => ''
    assert_equal nil, team.text
    first_translation = TeamTranslation.create!(:team => team, :locale => 'es', :text => 'text')
    assert_equal first_translation.text, team.reload.text
    default_translation = TeamTranslation.create!(:team => team, :locale => 'en', :text => 'text')
    assert_equal default_translation.text, team.reload.text
    real_translation = TeamTranslation.create!(:team => team, :locale => 'ru', :text => 'текст')
    assert_equal real_translation.text, team.reload.text
  end

  def test_all_translations_sorted_build_or_translation_getted
    team = Team.create!
    team_translation = TeamTranslation.create!(:team => team, :locale => 'en', :text => 'text')
    assert_equal team_translation, team.all_translations[:en]
    assert_equal 'ru', team.all_translations[:ru].locale
    team_translation_new = team.translations.build(:locale => :ru)
    assert_equal team_translation_new.locale.to_s, team.all_translations[:ru].locale
  end

  def test_all_translations_should_not_have_build_translations
    team = Team.create!
    assert_equal 0, team.translations.length
    team.all_translations
    assert_equal 0, team.translations.length
  end

  def test_has_translation?
    team = Team.create!
    assert !team.has_translation?(:en)
    team.translations.create!(:locale => 'en', :text => 'text')
    assert team.has_translation?(:en)
  end

  def test_named_scope_translated
    assert_equal 0, Team.translated(:en).count
    assert_equal 0, Team.translated(:ru).count
    team = Team.create!
    team.translations.create!(:locale => 'en', :text => 'text')
    assert_equal 0, Team.translated(:ru).count
    assert_equal 1, Team.translated(:en).count
    team.translations.create!(:locale => 'ru', :text => 'текст')
    assert_equal 1, Team.translated(:ru).count
  end
end
