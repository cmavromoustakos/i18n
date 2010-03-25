module ActionView
  module Helpers
    class InstanceTag
      def to_language_select_tag(options = {})
        options = options.stringify_keys
        add_default_name_and_id(options)
        value = value(object)
        
        all_languages = Language.all
        
        tag_text = "<select #{tag_options(options)}>"
        
        all_languages.each do |language|
          current_select = "selected" if Language::US_ENGLISH_ID == language.id
          tag_text << "<option value=\"#{language.id}\">#{language.language}</option>" 
        end
        tag_text << "</select>"
      end
      
      def to_translatable_input_field_tag(field_type, options = {})
        options = options.stringify_keys
        options["size"] = options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"] unless options.key?("size")
        options = DEFAULT_FIELD_OPTIONS.merge(options)
        if field_type == "hidden"
          options.delete("size")
        end
        options["type"] = field_type
        add_default_name_and_id(options)
        tag("input", options)
      end
      
      def to_translatable_text_area_field_tag(field_type, options = {})
        options = options.stringify_keys
        # options["size"] = options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"] unless options.key?("size")
        options = DEFAULT_FIELD_OPTIONS.merge(options)
        #if field_type == "hidden"
        #  options.delete("size")
        #end
        text_area_value = options.delete("value")
        options["type"] = field_type  
        add_default_name_and_id(options)
        html = tag("textarea", options)
        html << text_area_value if text_area_value
        html << "</textarea>"
        html
      end

      # TODO: Need to add a listener on the select to change the hidden field and value from the 
      #  TranslationWrapperFieldHelper::translation_wrapper_fields to redraw the form element
      # with the new values once the language has changed.
    end

    module TranslationWrapperFieldHelper
      def translation_wrapper_fields(object_name, method, options = {})
        objekt = options.delete(:object)   
        index =  options.delete(:index)       
        field_name = "#{object_name}[#{method}]"
        instance_tag = ActionView::Helpers::InstanceTag.new( field_name, 
                                                             :text,
                                                             self,
                                                             objekt)
        
        object_id = objekt.id.nil? ? "new" : objekt.id
        unique_tag_id =  "#{objekt.class.class_name}_#{method}_#{index}_#{object_id}"
        
        tag = instance_tag.to_translatable_input_field_tag(:text, options.merge({:id => unique_tag_id }))
        
        # Hidden field for key for translation wrapper
        tag << ActionView::Helpers::InstanceTag.new(field_name, 
                                                    :key, 
                                                    self, 
                                                    options.delete(:object)).tag("hidden", 
                                                                                                options.merge({:value => method }))
        
        instance_tag_lang_select = ActionView::Helpers::InstanceTag.new(field_name, :language, self, options.delete(:object))
        
        rdnumb = rand(1000)
        unique_select_tag_id =  "#{objekt.class.class_name}_#{method}_#{object_id}_#{index}_select"
        tag << instance_tag_lang_select.to_language_select_tag(options.merge({:id => unique_select_tag_id }))
        
        tag << "<script>
        
        
        $(\"#"+unique_select_tag_id+"\").change(function () {
      	language = $(this).children(\"option:selected\").attr(\"value\");	
        $.getJSON(\"/translations/\"+language+\"/#{objekt.class.table_name}/#{objekt.id}/#{method}.json\",
    		        function(data){
    								json= data;
    								if (json[\"text\"] == null) {
    									json[\"text\"] = \"\";
    								}
    								var input = $(\"#"+unique_tag_id+"\");
    								input.html(json[\"text\"]);
    								input.attr(\"value\", json[\"text\"]);
    								console.log(json[\"text\"]);

    		        });
    		 	});
         </script>"
      end
      
      
      def translation_wrapper_text_area(object_name, method, options = {})
        objekt = options.delete(:object)  
        index =  options.delete(:index)  
        field_name = "#{object_name}[#{method}]"
        
        instance_tag = ActionView::Helpers::InstanceTag.new( field_name, 
                                                             :text,
                                                             self,
                                                             objekt)
        
        object_id = objekt.id.nil? ? "new" : objekt.id
        unique_tag_id =  "#{objekt.class.class_name}_#{method}_#{index}_#{object_id}"
        
        tag = instance_tag.to_translatable_text_area_field_tag(:text, options.merge({:id => unique_tag_id }))
        
        # Hidden field for key for translation wrapper
        tag << ActionView::Helpers::InstanceTag.new(field_name, 
                                                    :key, 
                                                    self, 
                                                    options.delete(:object)).tag("hidden", 
                                                                                                options.merge({:value => method }))
        
        instance_tag_lang_select = ActionView::Helpers::InstanceTag.new(field_name, :language, self, options.delete(:object))
        
        unique_select_tag_id =  "#{objekt.class.class_name}_#{method}_#{object_id}_#{index}_select"
        tag << instance_tag_lang_select.to_language_select_tag(options.merge({:id => unique_select_tag_id }))
        
        
        tag << "<script>
        
        
        $(\"#"+unique_select_tag_id+"\").change(function () {
      	language = $(this).children(\"option:selected\").attr(\"value\");	
        $.getJSON(\"/translations/\"+language+\"/#{objekt.class.table_name}/#{objekt.id}/#{method}.json\",
    		        function(data){
    								json= data;
    								if (json[\"text\"] == null) {
    									json[\"text\"] = \"\";
    								}
    								var input = $(\"#"+unique_tag_id+"\");
    								input.html(json[\"text\"]);
    								input.attr(\"value\", json[\"text\"]);
    								console.log(json[\"text\"]);

    		        });
    		 	});
         </script>"
      end
      
      
    end
  end
end

ActionView::Base.send :include, ActionView::Helpers::TranslationWrapperFieldHelper

module ActionView
  module Helpers
    class FormBuilder
      def translation_wrapper(method, options = {})
        value = @object.send(method, :language => (options[:language] || Language::DEFAULT_CMS_LANGUAGE_ID))
        object_name_override = options.delete(:object_name)
        object_name_override ||= @object_name
        @template.translation_wrapper_fields(object_name_override, method,
                                             options.merge(:object => @object, :value => value))
      end
      
      def translation_wrapper_text_area(method, options = {})
        value = @object.send(method, :language => (options[:language] || Language::DEFAULT_CMS_LANGUAGE_ID))
        object_name_override = options.delete(:object_name)
        object_name_override ||= @object_name        
        @template.translation_wrapper_text_area(object_name_override, method,
                                             options.merge(:object => @object, :value => value))
      end
    end

  end
end

