module Assistant::Provided
  extend ActiveSupport::Concern

  def get_model_provider(ai_model)
    provider = registry.providers.compact.find { |provider| provider.supports_model?(ai_model) }

    if provider.nil?
      raise Provider::Error, "No provider supports AI model: #{ai_model}. Supported models: #{Message.supported_ai_models.join(', ')}"
    end

    provider
  end

  private
    def registry
      @registry ||= Provider::Registry.for_concept(:llm)
    end
end
