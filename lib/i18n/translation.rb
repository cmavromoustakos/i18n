module I18n
  class Translation < ActiveRecord::Base
    acts_as_versioned
    belongs_to( :translation_key, 
                :class_name => "I18n::TranslationKey")
    
    belongs_to :language
    
    validates_presence_of( :language_id, 
                           :message => "You must provide a language for the translation")
    
    validates_presence_of( :text,
                           :message => "attribute can not be empty" )
    
    def google_translate(to)
      raise ArgumentError.new("You must provide a language to translate to") unless to and to.is_a?(Language)
      base = 'http://ajax.googleapis.com/ajax/services/language/translate' 
      
      to = to.i18n_abbreviation
      from = self.language.i18n_abbreviation

      # assemble query params
      params = {
        :langpair => "#{from}|#{to}", 
        :q => self.text,
        :v => 1.0  
      }

      query = params.map{ |k,v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')

      # send get request
      response = Net::HTTP.get_response( URI.parse( "#{base}?#{query}" ) )
      
      json = JSON.parse( response.body )
      
      
      if json['responseStatus'] == 200
        json['responseData']['translatedText']
      else
        return nil
      end
    end
  end
end
