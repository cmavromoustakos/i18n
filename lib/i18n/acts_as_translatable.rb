module I18n  
  # This module provides any given class that includes it 2 different types of
  # of translations. An Instance and a Singleton tranlsation.
  #   
  # Below is an example usage
  #
  #    class Category  < ActiveRecord::Base
  #      acts_as_translatable( :attributes => [:name, :description])
  #      validates_presence_of :password                            
  #      
  #    end  
  #
  #
  #    The validates... methods will handle the creation of the key.
  #    The key is formed by taking the class name and storing it in owner, 
  #    appending the attribute name, and finally the type of validation.
  #
  #    so the example above would create an entry with the owner being the 
  #    category instance, and the key being password.validates_presence_of
  #
  module ActsAsTranslatable
    def self.included(base)  #:nodoc:
      base.extend(ClassMethods)
    end
  
    module ClassMethods  #:nodoc:
      def acts_as_translatable(options={})
        return unless Translation.table_exists? and TranslationKey.table_exists?
        
        configurations[:attributes] = options[:attributes]
        
        # ActiveRecord Associations
        has_many( :translation_keys, 
                  :class_name => "I18n::InstanceTranslationKey", 
                  :as => :owner, 
                  :include => :translations,
                  :dependent => :destroy,
                  :autosave => true,
                  :validate => true)
        
        
        # ActiveRecord Validations 
        
        attr_accessor :instance_translation_cache, :pending_save_translation_keys
        
        options[:attributes].each do |a|
          attr_accessor a.to_sym
        end
        
        create_dynamic_helper_methods   
        override_dynamic_finders
        include  ::I18n::ActsAsTranslatable::InstanceMethods
      end

      private
      # Override the default dynamic finders, for example Category.find_by_name
      # will by default do a select on the name attribute. We have to hook into 
      # if we hook into the find_by_name find_by_name_or_create should work, since
      # its super method should call this find by. 
      def override_dynamic_finders
        configurations[:attributes].each do |attr_name|
          find_by_attr = "self.find_by_#{attr_name}( translation_wrapper, options={} )"
          find_or_create_by_attr = "self.find_or_create_by_#{attr_name}( translation_wrapper, options ={} )"

          class_eval <<EOF
            def #{find_by_attr}
              if translation_wrapper.is_a?(String)
                @@translation_wrapper = TranslationWrapper.new(:text => translation_wrapper, :language => options[:language] || Language::US_ENGLISH_ID)
              else
                unless translation_wrapper.is_a?(TranslationWrapper) 
                  raise ArgumentError.new("This method takes a translation wrapper with text and a language set or string with :language(optional default - US english)") 
                else
                  @@translation_wrapper = translation_wrapper
                end
              end
              
              self.find(:first,
                        :joins => {:translation_keys => :translations},
                        :readonly => false,
                        :conditions => {
                                        :translation_keys => {:key_name => "#{attr_name}"}, 
                                        :translations => {:text => @@translation_wrapper.text, 
                                                          :language_id => @@translation_wrapper.language }
                                        }.merge(options[:conditions] || {})
                        )

            end

            def #{find_or_create_by_attr}
              object_found = #{find_by_attr}
                        
              object_found ||= self.create("#{attr_name}".to_sym => @@translation_wrapper )
              object_found
            end
            
EOF
        end
      end
      
      def create_dynamic_helper_methods        
        configurations[:attributes].each do |attr|
          class_eval do             
            define_method("#{attr}=".to_sym) do |*params|
              translation = nil 
              params = params.first if params.is_a?(Array)
              translation_wrapper = params
              
              if translation_wrapper.is_a?(Hash)
                translation_wrapper = TranslationWrapper.new(translation_wrapper)
              elsif translation_wrapper.is_a?(String)
                translation_wrapper = TranslationWrapper.new(:text => translation_wrapper, :language => Language::US_ENGLISH_ID)
              end
              
              return if !translation_wrapper
              
              # If a user explicitly send in a key then we will use that, otherwise we will use
              # the name of the attribute.
              key ||= translation_wrapper.key ||= attr
              key = key.to_s
                         
              # Look at non active record keys that were created also. Find will not look at the
              # local object cache. Also compact the keys and grab the last one that was added. Found
              # a bug where we were not calling compact and it was grabbing a nil object.
              translation_key ||= self.translation_keys.collect do |tk| 
                if tk.key_name == key
                  tk
                end
              end.compact.last
                            
              if !translation_key
                translation_key = InstanceTranslationKey.new( :key_name => key, 
                                                              :owner => self ) 
                self.translation_keys << translation_key
              end
              
              # This is needed because the find returns back an object that self does not know about.
              # So for example a = b.x
              # a.something = something_else
              # a.something == b.x.something is false. Since they are independent objects.
              # What I am doing here is using the index to access the chain of objects and modify it 
              # directly in the ActiveRecord chain so that autosave knows to save this child object also.              
              key_index = self.translation_keys.index(translation_key)
              
              translation = nil
              
              if key_index
                translation = self.translation_keys[key_index].translations.collect do |t|                  
                  t if t.language_id == translation_wrapper.language
                end.compact.last
              end
              
              if translation
                translation_index = self.translation_keys[key_index].translations.index(translation)
                
                self.translation_keys[key_index].translations[translation_index].text = translation_wrapper.text
              else
                translation = Translation.new(:language_id => translation_wrapper.language,
                                              :text => translation_wrapper.text,
                                              :translation_key => translation_key)
                translation_key.translations << translation
              end
                            
              self[attr.to_sym] = translation.text if translation_wrapper.language == Language::US_ENGLISH_ID
              
              # If the user does not pass a key in then store the value of the actual text
              # as the key.
              self[attr.to_sym] ||= key
              
              CACHE.delete(get_cache_key(attr.to_s, translation_wrapper.language)) if defined?(CACHE)
              translation.text              
            end
            
            
            # Getter
            define_method("#{attr}".to_sym) do |*params| 
              translation = nil
              
              # Caching logic would go here, We would use the key + model class as a lookup 
              # into the memcache store.
              language = params.first[:language] if params.first and params.first[:language] 
              
              language = language.id if language.is_a?(Language)
              
              language ||= Language::US_ENGLISH_ID
              
              if defined?(CACHE) and !self.new_record?
                translation = CACHE.fetch(get_cache_key(attr.to_s, language)) 
              end 
              
              if translation                                                           
                if params.first and params.first[:return_wrapper]                
                  return TranslationWrapper.new(:text => translation, :key => "#{attr.to_s}", :language => language)
                else 
                  return translation
                end
              end
              
              conditions = ["key_name = ? and translations.language_id = ?", 
                              "#{attr.to_s}", 
                              language]
                
              translation_key = self.translation_keys.find( :first, 
                                                              :include => :translations,
                                                              :conditions => conditions)

              translation = translation_key.translations.first.text if translation_key and !translation_key.translations.empty?
                
              if !translation
                I18N_LOGGER.error "view_text_lookup: Unable to locate string '#{attr}' for language #{language}"
                translation = self[attr.to_sym]
              elsif defined?(CACHE) and !self.new_record?
                CACHE.set(get_cache_key(attr.to_s, language), translation)
              end
              
              if params.first and params.first[:return_wrapper]                
                return TranslationWrapper.new(:text => translation, :key => "#{attr.to_s}", :language => language)
              end
              
              translation
            end # end define_method            
          end # end class_eval
        end # configurations[:attributes].each do |attr|
      end # end def override_dynamic_finders
    end # end module ClassMethods
    
    module InstanceMethods      
      def initialize(opt={})
        self.pending_save_translation_keys = []
        super(opt)        
      end
      
      def get_cache_key(key=nil, language_id=nil)
        "#{self.class.name.tableize}_#{self.id}_#{key}_language_#{language_id}"
      end
      
      def after_initialize
        self.pending_save_translation_keys = []
      end      
      
      private 
      def save_pending_translation_keys        
        self.pending_save_translation_keys.uniq.each do |t|
          t.save
        end
        self.pending_save_translation_keys = []
      end
    end
  end
end # end module I18n
