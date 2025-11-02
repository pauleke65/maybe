module Ai
  class ModelCatalog
    ModelOption = Data.define(:id, :name, :provider)

    class << self
      def available
        Provider::Registry.for_concept(:llm).providers.compact.flat_map do |provider|
          provider.respond_to?(:model_options) ? provider.model_options : []
        end
      end

      def default_model
        available.first&.id || default_fallback_model
      end

      private
        def default_fallback_model
          if defined?(Provider::Openai::MODELS)
            Provider::Openai::MODELS.keys.first
          else
            "gpt-4.1"
          end
        end
    end
  end
end
