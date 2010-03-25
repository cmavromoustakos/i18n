module I18n
  class SingletonTranslationKey < TranslationKey
    validates_presence_of :key_name
    validates_uniqueness_of :key_name, :scope => :klass
    
    def self.translate(options = {})
      # Note that options[:language] is really a language_id

      unless( options[:language] and options[:key] ) 
        raise ArgumentError.new("key and language are  required")
      end
      
      options[:language] = options[:language].id if options[:language].is_a?(Language)
      
      translation = CACHE.fetch(SingletonTranslationKey.get_cache_key(options[:key], options[:language], options[:klass])) if defined?(CACHE)
      
      return translation if translation

      # Not safe against sql injection
      if options[:klass]
        conditions = "translation_keys.klass = '#{options[:klass]}' AND "
      else
        conditions = "translation_keys.klass IS NULL AND "
      end        
      conditions << "translation_keys.key_name = '#{options[:key]}' AND translations.language_id = '#{options[:language]}'"
      
      translation = Translation.find( :first, 
                                      :joins => :translation_key,
                                      :conditions => conditions,
                                      :order => "translations.version DESC" )
      if translation
        CACHE.set(SingletonTranslationKey.get_cache_key(options[:key], options[:language], options[:klass]), translation) if defined?(CACHE)
      end
      translation
    end
    
    def self.get_cache_key(key=nil, language=nil, klass=nil)
      "#{klass}_#{key}_#{language}".split(' ').join('')
    end
  end
end
