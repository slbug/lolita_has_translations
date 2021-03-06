# encoding: utf-8
require File.dirname(__FILE__) + '/spec_helper'

describe 'HasTranslations' do
  it "should switch locales" do
    g = Group.create!(:name => "Sport")
    c = Category.create!(:name => "Golf", :groups => [g])
    z = News.create!(:title => "Tiger Woods sucks", :body => Faker::Lorem::paragraphs(10).join, :category_id => c.id)
    # translate
    g.translations.create!(:locale => 'lv', :name => "Sports")
    c.translations.create!(:locale => 'lv', :name => "Golfs")
    z.translations.create!(:locale => 'lv', :title => "Taigers Vuds nekam neder")
    
    g.name.should == "Sport"
    c.name.should == "Golf"
    z.title.should == "Tiger Woods sucks"

    I18n.locale = :lv
    
    g.name.should == "Sports"
    c.name.should == "Golfs"
    z.title.should == "Taigers Vuds nekam neder"

    z.category.name.should == "Golfs"
    z.category.groups.first.name.should == "Sports"

    z.destroy
    c.destroy
    g.destroy
  end

  #TODO: a lot more tests
end
