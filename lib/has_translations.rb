class ActiveRecord::Base
  # Provides ability to add the translations for the model using delegate pattern.
  # Uses has_many association to the ModelNameTranslation.
  #
  # For example you have model Article with attributes title and text.
  # You want that attributes title and text to be translated.
  # For this reason you need to generate new model ArticleTranslation.
  # In migration you need to add:
  #
  #   create_table :article_translations do |t|
  #     t.references :article, :null => false
  #     t.string :locale, :length => 2, :null => false
  #     t.string :name, :null => false
  #   end
  #
  #   add_index :articles, [:article_id, :locale], :unique => true, :name => 'unique_locale_for_article_id'
  #
  # And in the Article model:
  #
  #   translations :title, :text
  #
  # This will adds:
  #
  # * named_scope (translated) and has_many association to the Article model
  # * locale presence validation to the ArticleTranslation model.
  #
  # Notice: if you want to have validates_presence_of :article, you should use :inverse_of.
  # Support this by yourself. Better is always to use artile.translations.build() method.
  #
  # For more information please read API. Feel free to write me an email to:
  # dmitry.polushkin@gmail.com.
  #
  # ===
  #
  # You also can pass attributes and options to the translations class method:
  #
  #   translations :title, :text, :fallback => true, :writer => true, :nil => nil
  #
  # ===
  #
  # Configuration options:
  # 
  # * <tt>:fallback</tt> - if translation for the current locale not found.
  #   By default true.
  #   Uses algorithm of fallback:
  #   0) current translation (using I18n.locale);
  #   1) default locale (using I18n.default_locale);
  #   2) :nil value (see <tt>:nil</tt> configuration option)
  # * <tt>:reader</tt> - add reader attributes to the model and delegate them
  #   to the translation model columns. Add's fallback if it is set to true.
  # * <tt>:writer</tt> - add writer attributes to the model and assign them
  #   to the translation model attributes.
  # * <tt>:nil</tt> - when reader cant find string, it returns by default an
  #   empty string. If you want to change this setting for example to nil,
  #   add :nil => nil
  #
  # ===
  #
  # When you are using <tt>:writer</tt> option, you can create translations using
  # update_attributes method. For example:
  #
  #   Article.create!
  #   Article.update_attributes(:title => 'title', :text => 'text')
  #
  # ===
  #
  # <tt>translated</tt> named_scope is useful when you want to find only those
  # records that are translated to a specific locale.
  # For example if you want to find all Articles that is translated to an english
  # language, you can write: Article.translated(:en)
  #
  # <tt>has_translation?(locale)</tt> method, that returns true if object's model
  # have a translation for a specified locale
  #
  # <tt>translation(locale)</tt> method finds translation with specified locale.
  #
  # <tt>all_translations</tt> method that returns all possible translations in
  # ordered hash (useful when creating forms with nested attributes).
  def self.translations(*attrs)
    options = {
      :fallback => true,
      :reader => true,
      :writer => false,
      :nil => ''
    }.merge(attrs.extract_options!)
    options.assert_valid_keys([:fallback, :reader, :writer, :nil])
    
    class << self
      # adds :translations to :includes if current locale differs from default
      alias_method(:find_every_without_translations, :find_every) unless method_defined?(:find_every_without_translations)
      def find_every(*args)
        if args[0].kind_of?(Hash)
          args[0][:include] ||= []
          args[0][:include] << :translations
        end unless I18n.locale == I18n.default_locale
        find_every_without_translations(*args)
      end
      # Defines given class recursively
      # Example:
      # create_class('Cms::Text::Page', Object, ActiveRecord::Base)
      # => Cms::Text::Page
      def create_class(class_name, parent, superclass, &block)
        first,*other = class_name.split("::")
        if other.empty?
          klass = Class.new superclass, &block
          parent.const_set(first, klass)
        else
          klass = Class.new
          parent = unless parent.const_defined?(first)
            parent.const_set(first, klass)
          else
            first.constantize
          end
          create_class(other.join('::'), parent, superclass, &block)
        end
      end
      # defines "ModelNameTranslation" if it's not defined manualy
      def define_translation_class name, attrs
        klass = name.constantize rescue nil
        unless klass
          klass = create_class(name, Object, ActiveRecord::Base) do
            # set's real table name
            set_table_name name.sub('Translation','').constantize.table_name.singularize + "_translations"
            cattr_accessor :translate_attrs, :master_id
            # override validate to vaidate only translate fields from master Class
            def validate
              item = self.class.name.sub('Translation','').constantize.new(self.attributes.clone.delete_if{|k,_| !self.class.translate_attrs.include?(k.to_sym)})
              was_table_name = item.class.table_name
              item.class.set_table_name self.class.table_name
              item.valid? rescue
              self.class.translate_attrs.each do |attr|
                errors_on_attr = item.errors.on(attr)
                self.errors.add(attr,errors_on_attr) if errors_on_attr
              end
              item.class.set_table_name was_table_name
            end
            # sets real master_id it's aware of STI
            def self.extract_master_id name
              master_class = name.sub('Translation','').constantize
              class_name = !master_class.superclass.abstract_class? ? master_class.superclass.name : master_class.name
              self.master_id = :"#{class_name.demodulize.underscore}_id"
            end
          end
          klass.translate_attrs = attrs
          klass.extract_master_id(name)
        end
        klass
      end
      # creates translation table and adds missing fields
      # So at first add the "translations :name, :desc" in your model
      # then put YourModel.sync_translation_table! in db/seed.rb and run "rake db:seed"
      # Later adding more fields in translations array, just run agin "rake db:seed"
      # If you want to remove fields do it manualy, it's safer
      def sync_translation_table!
        translations_class = reflections[:translations].class_name.constantize
        translations_table = translations_class.table_name
        unless ActiveRecord::Migration::table_exists?(translations_table)
          ActiveRecord::Migration.create_table translations_table do |t|
            t.integer translations_class.master_id, :null => false
            t.string :locale, :null => false, :limit => 5
            columns_has_translations.each do |col|
              t.send(col.type,col.name)
            end
          end
          ActiveRecord::Migration.add_index translations_table, [translations_class.master_id, :locale], :unique => true
          translations_class.reset_column_information
        else
          changes = false
          columns_has_translations.each do |col|
            unless translations_class.columns_hash.has_key?(col.name)
              ActiveRecord::Migration.add_column(translations_table, col.name, col.type)
              changes = true
            end
          end
          translations_class.reset_column_information if changes
        end
      end
    end

    translation_class_name = "#{self.name}Translation"
    translation_class = self.define_translation_class(translation_class_name, attrs)
    belongs_to = self.name.demodulize.underscore.to_sym

    write_inheritable_attribute :has_translations_options, options
    class_inheritable_reader :has_translations_options

    write_inheritable_attribute :columns_has_translations, columns.collect{|col| col if attrs.include?(col.name.to_sym)}.compact
    class_inheritable_reader :columns_has_translations

    # forces given locale
    # I18n.locale = :lv
    # a = Article.find 18
    # a.title
    # => "LV title"
    # a.in(:en).title
    # => "EN title"
    def in locale
      @locale = locale
      self
    end
    
    def find_or_build_translation(*args)
      locale = args.first.to_s
      build = args.second.present?
      find_translation(locale) || (build ? self.translations.build(:locale => locale) : self.translations.new(:locale => locale))
    end

    def translation(locale)
      find_translation(locale.to_s)
    end

    def all_translations
      t = I18n.available_locales.map do |locale|
        [locale, find_or_build_translation(locale)]
      end
      ActiveSupport::OrderedHash[t]
    end

    def has_translation?(locale)
      return true if locale == I18n.default_locale
      find_translation(locale).present?
    end

    # if object is new, then nested slaves ar built for all available locales
    def build_nested_translations
      if (I18n.available_locales.size - 1) > self.translations.size
        I18n.available_locales.clone.delete_if{|l| l == I18n.default_locale}.each do |l|
          options = {:locale => l.to_s}
          options[self.class.reflections[:translations].class_name.constantize.master_id] = self.id unless self.new_record?
          self.translations.build(options) unless self.translations.map(&:locale).include?(l.to_s)
        end
      end
    end

    if options[:reader]
      attrs.each do |name|
        send :define_method, name do
          unless I18n.default_locale == (@locale || I18n.locale)
            translation = self.translation(@locale || I18n.locale)
            if translation.nil?
              if has_translations_options[:fallback]
                (self[name].nil? || self[name].blank?) ? has_translations_options[:nil] : self[name].set_origins(self,name)
              else
                has_translations_options[:nil]
              end
            else
              if @return_raw_data
                (self[name].nil? || self[name].blank?) ? has_translations_options[:nil] : self[name].set_origins(self,name)
              else
                translation.send(name).set_origins(self,name)
              end
            end
          else
            (self[name].nil? || self[name].blank?) ? has_translations_options[:nil] : self[name].set_origins(self,name)
          end
        end
      end
    end

    #FIXME: implement this for update_attributes, save ...
    #    if options[:writer]
    #      attrs.each do |name|
    #        send :define_method, "#{name}=" do |value|
    #          unless I18n.default_locale == (@locale || I18n.locale)
    #            translation = find_or_build_translation((@locale || I18n.locale), true)
    #            translation.send(:"#{name}=", value)
    #          else
    #            self[name] = value
    #          end
    #        end
    #      end
    #    end

    has_many :translations, :class_name => translation_class_name, :foreign_key => translation_class.master_id, :dependent => :destroy
    accepts_nested_attributes_for :translations, :allow_destroy => true, :reject_if => proc { |attributes| columns_has_translations.collect{|col| attributes[col.name].blank? ? nil : 1}.compact.empty? }
    translation_class.belongs_to belongs_to
    translation_class.validates_presence_of :locale
    translation_class.validates_uniqueness_of :locale, :scope => translation_class.master_id

    # Workaround to support Rails 2
    scope_method = if ActiveRecord::VERSION::MAJOR < 3 then :named_scope else :scope end

    send scope_method, :translated, lambda { |locale| {:conditions => ["#{translation_class.table_name}.locale = ?", locale.to_s], :joins => :translations} }

    private

    def find_translation(locale)
      locale = locale.to_s
      translations.detect { |t| t.locale == locale }
    end
  end
end