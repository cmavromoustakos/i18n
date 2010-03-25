require 'test_helper'
require 'i18n/action_view/helpers/translation_helper'

class TranslationHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TranslationHelper
  
  def test_run_substitutions
    result = run_substitutions "this is text with a :special field", :special => "FNORD"
    assert_equal "this is text with a FNORD field", result
  end
  
end
