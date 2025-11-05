require "test_helper"

class Provider::GeminiTest < ActiveSupport::TestCase
  include LLMInterfaceTest

  setup do
    @subject = @gemini = Provider::Gemini.new(ENV.fetch("GEMINI_API_KEY", "test-gemini-key"))
    @subject_model = "gemini-2.5-flash"
  end

  test "supports gemini models" do
    assert @gemini.supports_model?("gemini-2.5-flash")
    assert @gemini.supports_model?("gemini-2.5-pro")
    assert @gemini.supports_model?("gemini-2.5-flash-lite")
    assert_not @gemini.supports_model?("gpt-4.1")
  end
end
