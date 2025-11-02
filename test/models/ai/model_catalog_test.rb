require "test_helper"

class Ai::ModelCatalogTest < ActiveSupport::TestCase
  test "default_model falls back to openai model when providers unavailable" do
    assert_equal Provider::Openai::MODELS.keys.first, Ai::ModelCatalog.default_model
  end

  test "available returns options for configured providers" do
    assert_kind_of Array, Ai::ModelCatalog.available
  end
end
