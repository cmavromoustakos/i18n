module ActionView
  module Helpers
    module TranslationHelper      
      # This gets the site abbreviation from the params or from the current url
      # Note that the routes should have gotten the site abbreviation from the url and
      # passed it in as a param, so in general it will be the former that is used
      def site_abbreviation
        return params[:site_abbreviation] if params && params[:site_abbreviation]
        return params[:id] if params && params[:id]
        return cookies[:site_abbreviation] unless cookies[:site_abbreviation].blank?
        return "us"
        throw Exception.new("Unable to determine site_abbreviation. No params and no url present")
      end
      
      
      def get_current_language_id(options = {})
        # Allow for the user to pass id, string, or Language object for this method. 
        language = Language.find(options[:language]) if options[:language] and options[:language].is_a?(Integer)
        language ||= options[:language] if options[:language] and options[:language].is_a?(Language) 
        language ||= Language.find_by_language(options[:language]) if options[:language] and options[:language].is_a?(String) 
        
        if options[:language]
          if options[:language] and !language
            throw Exception.new("Language #{language} passed to get_current_language_id is unknown")
          else
            return language.id
          end
        end
        
        if(!site = Site.find(:first, :conditions => {:abbreviation => sa}))
          raise Exception.new("Site with abbreviation '#{sa}' does not exist")
        else
          language_id = site.language_id
        end
      end

      # This function returns a string pulled out of the SystemArticle table,
      # with the given name.  First it looks using the specified controller.  If nothing
      # is found it looks without a controller.
      # Options are
      #   :controller => somecontroller
      #     Note that you *must* specify this if you aren't calling this from a controller or view
      #   :url
      #   :site_abbreviation
      #   :language
      #     Specifying one will determine what language is fetched.  If you specify the url, it
      #     will use the get_site_abbreviation_from_url method to figure out the site_abbreviation
      #     If you don't specify one, it uses the site_abbreviation method to get it
      #   :missing_ok => true
      #     It is an error to fail to find the string, unless you specify the
      def view_text(string_name, options={})
        raise Exception.new("Parameter string_name may not be blank") if string_name.blank?

        controller ||= options[:controller] ||= self.controller_name

        # If you are on the production server, you can only see strings set to live
        # mode.  If you are on a development or staging server, you can see draft or ready status
        language_id = get_current_language_id(options)

        # First, try to look up the string in the specified controller
        # Note: we get the one with the highest version number
        translation = I18n::SingletonTranslationKey.translate( :klass => controller, 
                                                               :language => language_id,
                                                               :key => string_name )

        if !translation
          # if it doesn't work, try to look up the string globally.
          translation = I18n::SingletonTranslationKey.translate( :language => language_id,
                                                                 :key => string_name )
        end

        # if we found something, we're good, run the subs
        if translation && translation.text
          return run_substitutions translation.text, options[:subs]
        end

        if options[:missing_ok] == true
          return ""
        else
          # Rather than fail if we can not find the translation, put the key in place of
          # the translation and log a tranlsation error in the i18n.log which is defined in
          # config/initializers/i18n_logger.rb
          language = Language.find(language_id)
          I18N_LOGGER.error "view_text_lookup: Unable to locate string '#{string_name}' " +
            "for language #{language.language} that belongs to controller #{controller}"
          return "#{string_name}-#{language_id}"
        end
      end
      
      # Rails 2.3 compatibility. The I18N uses these we may want to use translate so if they ever
      # get their shit together we can switch to a more standard approach to storing 
      # internationaliztion strings.
      alias :translate :view_text
      alias :t :view_text      


      # This function returns a string pulled out of the translations table,
      # with the given name.  First it looks using the specified controller.  If nothing
      # is found it looks without a controller.
      # Options are
      #   :url
      #   :site_abbreviation
      #   :language
      #     Specifying one will determine what language is fetched.  If you specify the url, it
      #     will use the get_site_abbreviation_from_url method to figure out the site_abbreviation
      #     If you don't specify one, it uses the site_abbreviation method to get it
      #   :missing_ok => true
      #     It is an error to fail to find the string, unless you specify the
      def view_error_text(object, error_key, options = {})
        raise Exception.new("Parameter string_name may not be blank") if error_key.blank?
        
        controller ||= options[:controller] ||= self.controller_name

        # If you are on the production server, you can only see strings set to live
        # mode.  If you are on a development or staging server, you can see draft or ready status
        language_id = get_current_language_id(options)

        # First, try to look up the string in the specified controller
        # Note: we get the one with the highest version number
        translation = I18n::SingletonTranslationKey.translate( :klass => object, 
                                                                    :language => language_id,
                                                                    :key => error_key )
        
        # Model errors are bound directly to an error we do not want to look for this key on the global level 
        
        # if we found something, we're good
        return translation.text if translation && translation.text

        # if not, we can optionally return an empty string
        if options[:missing_ok] == true
          return ""
        else
          # Rather than fail if we can not find the translation, put the key in place of
          # the translation and log a tranlsation error in the i18n.log which is defined in
          # config/initializers/i18n_logger.rb
          language = Language.find(language_id)
          I18N_LOGGER.error "view_text_lookup: Unable to locate string '#{error_key}' " +
            "for language #{language.language} that belongs to object  #{object}"
          return "trasnlation-missing: #{error_key} - lang: #{language_id}"
        end
      end  
    end
  end
end
