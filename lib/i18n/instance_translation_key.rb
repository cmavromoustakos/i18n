module I18n
  class InstanceTranslationKey < TranslationKey
    validates_presence_of :owner
    validates_presence_of :key_name
    validates_uniqueness_of :key_name, :scope => [:owner_type, :owner_id]
    
    def self.translate(options = {})
      # Note that options[:language] is really a language_id
      # Here, owner must really be a particular instance

      unless( options[:owner] and options[:language] and options[:key] ) 
        raise ArgumentError.new("owner, key, and language are all required")
      end

      if options[:owner].is_a?(Fixnum)
        raise ArgumentError.new("you must pass a real owner, not an id to translate")
      end
      
      conditions = "translation_keys.owner_type = '#{options[:owner].class.name}' AND " +
        "translation_keys.owner_id = #{options[:owner].id} AND " +
        "translation_keys.key_name = '#{options[:key]}' AND " +
        "translations.language_id = '#{options[:language]}'"
      
      Translation.find( :first, 
                        :joins => :translation_key,
                        :conditions => conditions,
                        :order => "translations.version DESC" )
    end
  end
end
