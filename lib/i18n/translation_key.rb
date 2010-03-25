module I18n
  class TranslationKey < ActiveRecord::Base
    
    # ActiveRecord Associations
    has_many( :translations, 
              :class_name => "I18n::Translation", 
              :dependent => :destroy,
              :validate => true,
              :autosave => true) 
    
    belongs_to :owner, :polymorphic => true

    # ActiveRecord Validations
    validates_presence_of :key_name, :message => "You must have a key for a translation key"
        
    # State machine for Translation key
    state_machine :state, :initial => :draft do
      event :activate do
        transition all => :live
      end
      
      event :draft do
        transition all => :draft
      end
      
      event :archive do
        transition all => :archived
      end
      
      event :prepare do
        transition all => :ready
      end    
    end
    
    def self.valid_states_for_environment
      states = []
      if RAILS_ENV == "production"
        states = ["live"]
      else
        states = ["live", "ready", "draft"]
      end
      
      states
    end
  end
end
