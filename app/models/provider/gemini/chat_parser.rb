class Provider::Gemini::ChatParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :object

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      # Generate a unique ID since Gemini doesn't provide one
      @response_id ||= SecureRandom.uuid
    end

    def response_model
      object.dig("modelVersion") || "gemini-2.5-flash"
    end

    def messages
      candidates = object.dig("candidates") || []

      candidates.flat_map do |candidate|
        content = candidate.dig("content")
        next [] unless content

        parts = content.dig("parts") || []
        text_parts = parts.select { |part| part.key?("text") }

        text_parts.map do |part|
          ChatMessage.new(
            id: SecureRandom.uuid,
            output_text: part.dig("text") || ""
          )
        end
      end.compact
    end

    def function_requests
      candidates = object.dig("candidates") || []

      candidates.flat_map do |candidate|
        content = candidate.dig("content")
        next [] unless content

        parts = content.dig("parts") || []
        function_parts = parts.select { |part| part.key?("functionCall") }

        function_parts.map do |part|
          function_call = part.dig("functionCall")
          ChatFunctionRequest.new(
            id: SecureRandom.uuid,
            call_id: SecureRandom.uuid,
            function_name: function_call.dig("name"),
            function_args: function_call.dig("args")
          )
        end
      end.compact
    end
end
