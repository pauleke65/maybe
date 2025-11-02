class Provider::Gemini < Provider
  include Provider::LlmConcept

  Error = Class.new(Provider::Error)

  MODELS = {
    "gemini-1.5-flash" => {
      name: "Gemini 1.5 Flash (Google)",
      api_model: "gemini-1.5-flash-latest"
    }
  }.freeze

  def initialize(api_key)
    @api_key = api_key
  end

  def supports_model?(model)
    MODELS.key?(model)
  end

  def model_options
    MODELS.map do |id, attrs|
      Ai::ModelCatalog::ModelOption.new(
        id: id,
        name: attrs[:name],
        provider: :gemini
      )
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      raise Error, "Model '#{model}' is not supported by Gemini" unless supports_model?(model)

      response_text = fetch_response_text(
        prompt: prompt,
        model: model,
        instructions: instructions,
        function_results: function_results
      )

      chat_response = build_chat_response(model:, text: response_text)

      if streamer.present?
        stream_chunk = Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: response_text)
        streamer.call(stream_chunk)
        streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: chat_response))
      end

      chat_response
    end
  end

  private
    attr_reader :api_key

    def fetch_response_text(prompt:, model:, instructions:, function_results: [])
      body = {
        contents: [
          {
            role: "user",
            parts: [
              { text: build_prompt(prompt, function_results) }
            ]
          }
        ]
      }

      if instructions.present?
        body[:system_instruction] = {
          role: "system",
          parts: [ { text: instructions } ]
        }
      end

      response = connection.post("models/#{MODELS.fetch(model)[:api_model]}:generateContent") do |req|
        req.params["key"] = api_key
        req.body = body
      end

      parse_text_response(response.body)
    end

    def build_prompt(prompt, function_results)
      return prompt if function_results.blank?

      <<~PROMPT.strip
        Tool results:
        #{JSON.pretty_generate(function_results)}

        User prompt:
        #{prompt}
      PROMPT
    end

    def parse_text_response(payload)
      candidate = payload.fetch("candidates", []).first

      raise Error, "Gemini returned no candidates" if candidate.nil?

      text_parts = candidate.fetch("content", {}).fetch("parts", []).map { |part| part["text"] }.compact

      raise Error, "Gemini returned an empty response" if text_parts.empty?

      text_parts.join("\n")
    end

    def build_chat_response(model:, text:)
      Provider::LlmConcept::ChatResponse.new(
        id: SecureRandom.uuid,
        model: model,
        messages: [
          Provider::LlmConcept::ChatMessage.new(
            id: SecureRandom.uuid,
            output_text: text
          )
        ],
        function_requests: []
      )
    end

    def connection
      @connection ||= Faraday.new(url: "https://generativelanguage.googleapis.com/v1beta/") do |faraday|
        faraday.request :json
        faraday.request :retry
        faraday.response :json, content_type: /json/
      end
    end
end
