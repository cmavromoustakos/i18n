module ActionView  
  module Helpers
    module ActiveRecordHelper
      def error_messages_for(*params)
        options = params.extract_options!.symbolize_keys
        language = options.delete(:language)
        
        if object = options.delete(:object)
          objects = [object].flatten
        else
          objects = params.collect {|object_name| instance_variable_get("@#{object_name}") }.compact
        end

        count  = objects.inject(0) {|sum, object| sum + object.errors.count }
        unless count.zero?
          html = {}
          [:id, :class].each do |key|
            if options.include?(key)
              value = options[key]
              html[key] = value unless value.blank?
            else
              html[key] = 'errorExplanation'
            end
          end
          options[:object_name] ||= params.first

          header_message = if options.include?(:header_message)
                             options[:header_message]
                           else
                             object_name = options[:object_name].to_s.gsub('_', ' ')
                             object_name = view_text(object.class.name, :language => language)
                           end
          
          message = options[:message] if options.include?(:message)  
          error_messages = objects.map do |object|
            object.errors.collect { |column,error| translate_error(object, column, error, language) }
          end

          contents = ''
          contents << content_tag(options[:header_tag] || :h2, header_message) unless header_message.blank?
          contents << content_tag(:p, message) unless message.blank?
          contents << content_tag(:ul, error_messages)
          
          content_tag(:div, contents, html)
        else
          ''
        end
      end

      def translate_error(object=nil, error_key=nil, error_value=nil, language=nil)
        content_tag( :li, view_error_text(object.class.name.tableize, error_value, :language => language) )
      end

    end
  end
end
