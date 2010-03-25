module ActiveRecord
  module Validations
    module ClassMethods
      def validates_length_of(*attrs)
        # Merge given options with defaults.
        options = {
          :tokenizer => lambda {|value| value.split(//)}
        }.merge(DEFAULT_VALIDATION_OPTIONS)
        options.update(attrs.extract_options!.symbolize_keys)

        # Ensure that one and only one range option is specified.
        range_options = ALL_RANGE_OPTIONS & options.keys
        case range_options.size
        when 0
          raise ArgumentError, 'Range unspecified.  Specify the :within, :maximum, :minimum, or :is option.'
        when 1
          # Valid number of options; do nothing.
        else
          raise ArgumentError, 'Too many range options specified.  Choose only one.'
        end

        # Get range option and value.
        option = range_options.first
        option_value = options[range_options.first]
        key = {:is => :wrong_length, :minimum => :too_short, :maximum => :too_long}[option]
        case option
        when :within, :in
          raise ArgumentError, ":#{option} must be a Range" unless option_value.is_a?(Range)
          
          validates_each(attrs, options) do |record, attr, value|
            custom_message = options[:message] || "#{attr}.validates_length_of"          
            
            value = options[:tokenizer].call(value) if value.kind_of?(String)
            if value.nil? or value.size < option_value.begin
              record.errors.add(attr, :too_short, :default => custom_message || options[:too_short], :count => option_value.begin)
            elsif value.size > option_value.end
              record.errors.add(attr, :too_long, :default => custom_message || options[:too_long], :count => option_value.end)
            end
          end
        when :is, :minimum, :maximum
          raise ArgumentError, ":#{option} must be a nonnegative Integer" unless option_value.is_a?(Integer) and option_value >= 0
          
          # Declare different validations per option.
          validity_checks = { :is => "==", :minimum => ">=", :maximum => "<=" }
          
          validates_each(attrs, options) do |record, attr, value|
            custom_message = options[:message] || "#{attr}.validates_length_of"
            
            value = options[:tokenizer].call(value) if value.kind_of?(String)
            unless !value.nil? and value.size.method(validity_checks[option])[option_value]
              record.errors.add(attr, key, :default => custom_message, :count => option_value)
            end
          end
        end
      end

      def validates_presence_of(*attr_names)
        configuration = {
          :on => :save,
        }
        configuration.update(attr_names.extract_options!)

        # can't use validates_each here, because it cannot cope with nonexistent attributes,
        # while errors.add_on_empty can
        send(validation_method(configuration[:on]), configuration) do |record|
          attr_names.each do |attr_name|
            configuration[:message] ||= "#{attr_name}.validates_presence_of"          
            record.errors.add_on_blank(attr_name, configuration[:message])
          end
        end
      end
      
      def validates_confirmation_of(*attr_names)
        configuration = { :on => :save }
        configuration.update(attr_names.extract_options!)

        attr_accessor(*(attr_names.map { |n| "#{n}_confirmation" }))

        validates_each(attr_names, configuration) do |record, attr_name, value|
          unless record.send("#{attr_name}_confirmation").nil? or value == record.send("#{attr_name}_confirmation")
            configuration[:message] ||= "#{attr_name}.validates_confirmation_of"          
            record.errors.add(attr_name, :confirmation, :default => configuration[:message])
          end
        end
      end

      def validates_uniqueness_of(*attr_names)
        configuration = { :case_sensitive => true }
        configuration.update(attr_names.extract_options!)

        validates_each(attr_names,configuration) do |record, attr_name, value|
          # The check for an existing value should be run from a class that
          # isn't abstract. This means working down from the current class
          # (self), to the first non-abstract class. Since classes don't know
          # their subclasses, we have to build the hierarchy between self and
          # the record's class.
          class_hierarchy = [record.class]
          while class_hierarchy.first != self
            class_hierarchy.insert(0, class_hierarchy.first.superclass)
          end

          # Now we can work our way down the tree to the first non-abstract
          # class (which has a database table to query from).
          finder_class = class_hierarchy.detect { |klass| !klass.abstract_class? }

          column = finder_class.columns_hash[attr_name.to_s]

          if value.nil?
            comparison_operator = "IS ?"
          elsif column.text?
            comparison_operator = "#{connection.case_sensitive_equality_operator} ?"
            value = column.limit ? value.to_s.mb_chars[0, column.limit] : value.to_s
          else
            comparison_operator = "= ?"
          end

          sql_attribute = "#{record.class.quoted_table_name}.#{connection.quote_column_name(attr_name)}"

          if value.nil? || (configuration[:case_sensitive] || !column.text?)
            condition_sql = "#{sql_attribute} #{comparison_operator}"
            condition_params = [value]
          else
            condition_sql = "LOWER(#{sql_attribute}) #{comparison_operator}"
            condition_params = [value.mb_chars.downcase]
          end

          if scope = configuration[:scope]
            Array(scope).map do |scope_item|
              scope_value = record.send(scope_item)
              condition_sql << " AND " << attribute_condition("#{record.class.quoted_table_name}.#{scope_item}", scope_value)
              condition_params << scope_value
            end
          end

          unless record.new_record?
            condition_sql << " AND #{record.class.quoted_table_name}.#{record.class.primary_key} <> ?"
            condition_params << record.send(:id)
          end

          finder_class.with_exclusive_scope do
            if finder_class.exists?([condition_sql, *condition_params])
              configuration[:message] ||= "#{attr_name}.validates_uniqueness_of"          
              record.errors.add(attr_name, :taken, :default => configuration[:message], :value => value)
            end
          end
        end
      end

      def validates_format_of(*attr_names)
        configuration = { :on => :save, :with => nil }
        configuration.update(attr_names.extract_options!)

        raise(ArgumentError, "A regular expression must be supplied as the :with option of the configuration hash") unless configuration[:with].is_a?(Regexp)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          unless value.to_s =~ configuration[:with]
            configuration[:message] ||= "#{attr_name}.validates_format_of"
            record.errors.add(attr_name, :invalid, :default => configuration[:message], :value => value)
          end
        end
      end
      
      def validates_inclusion_of(*attr_names)
        configuration = { :on => :save }
        configuration.update(attr_names.extract_options!)

        enum = configuration[:in] || configuration[:within]

        raise(ArgumentError, "An object with the method include? is required must be supplied as the :in option of the configuration hash") unless enum.respond_to?(:include?)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          unless enum.include?(value)
            configuration[:message] ||= "#{attr_name}.validates_inclusion_of"
            record.errors.add(attr_name, :inclusion, :default => configuration[:message], :value => value)
          end
        end
      end

      def validates_exclusion_of(*attr_names)
        configuration = { :on => :save }
        configuration.update(attr_names.extract_options!)

        enum = configuration[:in] || configuration[:within]

        raise(ArgumentError, "An object with the method include? is required must be supplied as the :in option of the configuration hash") unless enum.respond_to?(:include?)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          if enum.include?(value)
            configuration[:message] ||= "#{attr_name}.validates_exclusion_of"
            record.errors.add(attr_name, :exclusion, :default => configuration[:message], :value => value)
          end
        end
      end

      def validates_associated(*attr_names)
        configuration = { :on => :save }
        configuration.update(attr_names.extract_options!)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          unless (value.is_a?(Array) ? value : [value]).collect { |r| r.nil? || r.valid? }.all?
            configuration[:message] ||= "#{attr_name}.validates_associated"
            record.errors.add(attr_name, :invalid, :default => configuration[:message], :value => value)
          end
        end
      end


      def validates_numericality_of(*attr_names)
        configuration = { :on => :save, :only_integer => false, :allow_nil => false }
        configuration.update(attr_names.extract_options!)
        numericality_options = ALL_NUMERICALITY_CHECKS.keys & configuration.keys

        (numericality_options - [ :odd, :even ]).each do |option|
          raise ArgumentError, ":#{option} must be a number" unless configuration[option].is_a?(Numeric)
        end

        validates_each(attr_names,configuration) do |record, attr_name, value|
          raw_value = record.send("#{attr_name}_before_type_cast") || value
          next if configuration[:allow_nil] and raw_value.nil?

          if configuration[:only_integer]
            unless raw_value.to_s =~ /\A[+-]?\d+\Z/
              configuration[:message] ||= "#{attr_name}.validates_numericality_of"
              record.errors.add(attr_name, :not_a_number, :value => raw_value, :default => configuration[:message])
              next
            end
            raw_value = raw_value.to_i
          else
            begin
              raw_value = Kernel.Float(raw_value)
            rescue ArgumentError, TypeError
              configuration[:message] ||= "#{attr_name}.validates_numericality_of"
              record.errors.add(attr_name, :not_a_number, :value => raw_value, :default => configuration[:message])
              next
            end
          end

          numericality_options.each do |option|
            case option
            when :odd, :even
              unless raw_value.to_i.method(ALL_NUMERICALITY_CHECKS[option])[]
                configuration[:message] ||= "#{attr_name}.validates_numericality_of"
                record.errors.add(attr_name, option, :value => raw_value, :default => configuration[:message])                
              end
            else
              configuration[:message] ||= "#{attr_name}.validates_numericality_of"
              record.errors.add(attr_name, 
                                option, 
                                :default => configuration[:message], 
                                :value => raw_value, 
                                :count => configuration[option]) unless raw_value.method(ALL_NUMERICALITY_CHECKS[option])[configuration[option]]
            end
          end
        end
      end

      def validates_acceptance_of(*attr_names)
        configuration = { :on => :save, :allow_nil => true, :accept => "1" }        
        configuration.update(attr_names.extract_options!)
        
        configuration[:message] ||= "#{attr_name}.validates_acceptance_of"
        
        db_cols = begin
          column_names
        rescue Exception # To ignore both statement and connection errors
          []
        end
        names = attr_names.reject { |name| db_cols.include?(name.to_s) }
        attr_accessor(*names)

        validates_each(attr_names,configuration) do |record, attr_name, value|
          unless value == configuration[:accept]
            record.errors.add(attr_name, :accepted, :default => configuration[:message])
          end
        end
      end
      
    end
  end
end
