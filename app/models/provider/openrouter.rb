class Provider::Openrouter < Provider
  include Provider::LlmConcept

  Error = Class.new(Provider::Error)

  MODELS = {
    "openrouter/anthropic/claude-3-haiku" => "Claude 3 Haiku (OpenRouter)"
  }.freeze

  def initialize(api_key)
    @api_key = api_key
  end

  def supports_model?(model)
    MODELS.key?(model)
  end

  def model_options
    MODELS.map do |id, name|
      Ai::ModelCatalog::ModelOption.new(
        id: id,
        name: name,
        provider: :openrouter
      )
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      raise Error, "Model '#{model}' is not supported by OpenRouter" unless supports_model?(model)

      response_body = connection.post("/chat/completions") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["HTTP-Referer"] = ENV.fetch("OPENROUTER_SITE_URL", "https://maybe.co")
        req.headers["X-Title"] = ENV.fetch("OPENROUTER_APP_NAME", "Maybe")
        req.body = build_request_body(
          model: model,
          prompt: prompt,
          instructions: instructions,
          function_results: function_results
        )
      end.body

      text = extract_message_text(response_body)

      chat_response = build_chat_response(model:, response_body:, text: text)

      if streamer.present?
        streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: text))
        streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: chat_response))
      end

      chat_response
    end
  end

  private
    attr_reader :api_key

    def build_request_body(model:, prompt:, instructions:, function_results: [])
      messages = []
      messages << { role: "system", content: instructions } if instructions.present?

      if function_results.present?
        messages << {
          role: "system",
          content: "Tool results available: #{JSON.generate(function_results)}"
        }
      end

      messages << { role: "user", content: prompt }

      {
        model: model,
        messages: messages
      }
    end

    def extract_message_text(payload)
      choices = payload.fetch("choices", [])
      raise Error, "OpenRouter returned no choices" if choices.empty?

      message = choices.first.fetch("message", {})
      content = extract_content_text(message["content"])
      raise Error, "OpenRouter returned an empty response" if content.blank?

      content
    end

    def extract_content_text(content)
      case content
      when Array
        content.map { |part| part["text"] || part["content"] }.compact.join("\n")
      else
        content
      end
    end

    def build_chat_response(model:, response_body:, text:)
      Provider::LlmConcept::ChatResponse.new(
        id: response_body["id"],
        model: model,
        messages: [
          Provider::LlmConcept::ChatMessage.new(
            id: response_body["id"],
            output_text: text
          )
        ],
        function_requests: []
      )
    end

    def connection
      @connection ||= Faraday.new(url: "https://openrouter.ai/api/v1") do |faraday|
        faraday.request :json
        faraday.request :retry
        faraday.response :json, content_type: /json/
      end
    end
end
