module I18n
  class TranslationWrapper
    attr_accessor :language, :key, :text
    attr_accessor :translation, :translation_key
    
    def initialize(options = {})
      options = options.symbolize_keys
        
      self.key ||= options[:key]
      self.text ||= options[:text]

      self.language ||= options[:language]
      self.language = self.language.to_i if self.language and self.language.is_a?(String)
      self.language = self.language if self.language and self.language.is_a?(Integer)
      self.language = self.language.id if self.language and language.is_a?(Language)
      self.language ||= Language::US_ENGLISH_ID
            
      self
    end    
  end
end
