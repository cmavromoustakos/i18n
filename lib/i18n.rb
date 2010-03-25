# I18n
require 'state_machine'

require 'i18n/acts_as_translatable'
ActiveRecord::Base.send(:include, I18n::ActsAsTranslatable)

require 'i18n/active_record/validations'
require 'i18n/active_record/error'
require 'i18n/action_view/helpers/active_record_helper'
require 'i18n/action_view/helpers/translation_helper'
require 'i18n/action_view/helpers/form_helper'


ActionController::Base.send(:include, ActionView::Helpers::TranslationHelper)
ActionController::Base.send(:include, ActionView::Helpers::TranslationWrapperFieldHelper)
ActionMailer::Base.send(:include, ActionView::Helpers::TranslationHelper)

Dir[File.join(File.dirname(__FILE__), "/i18n/**/*.rb")].each { |f| require f }
