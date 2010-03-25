module ActiveRecord
  # Raised by <tt>save!</tt> and <tt>create!</tt> when the record is invalid.  Use the
  # +record+ method to retrieve the record which did not validate.
  #   begin
  #     complex_operation_that_calls_save!_internally
  #   rescue ActiveRecord::RecordInvalid => invalid
  #     puts invalid.record.errors
  #   end
  class Errors
    def each(l=nil)
      if l.nil?
        language_id = nil
      elsif l.is_a?(Fixnum)
        language = nil
        language_id = l
      elsif l.is_a?(Language)
        language = l
        language_id = l.id
      else
        language_id = nil
      end
      if language_id
        @errors.each_key do |attr| 
          @errors[attr].each do |error| 
            klass = error.base.class.name.tableize
            t = I18n::SingletonTranslationKey.translate( :language => language_id, 
                                                              :klass => klass,
                                                              :key => error.message) 
            # Do we want to look for this key on a global level?
            if !t
              language ||= Language.find(language_id)
              I18N_LOGGER.error "errors.each: Unable to locate key '#{error.message}' " +
                "for language #{language.language} that belongs to klass #{klass}"
              txt = "#{klass}-#{error.message}-#{language_id}"
            else
              txt = t.text
            end
            yield attr, txt
          end
        end
      else
        @errors.each_key { |attr| @errors[attr].each { |error| yield attr, error.message } }
      end
    end
  end
end
