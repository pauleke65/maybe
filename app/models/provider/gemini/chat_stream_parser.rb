class Provider::Gemini::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    # Gemini streaming sends chunks with candidates
    candidates = object.dig("candidates")
    return nil unless candidates&.any?

    candidate = candidates.first
    content = candidate.dig("content")
    return nil unless content

    parts = content.dig("parts") || []

    # Check if this is a text part
    text_part = parts.find { |part| part.key?("text") }
    if text_part
      return Chunk.new(type: "output_text", data: text_part.dig("text"))
    end

    # Check if this is the final response with finish_reason
    finish_reason = candidate.dig("finishReason")
    if finish_reason
      return Chunk.new(type: "response", data: parse_response(object))
    end

    nil
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk

    def parse_response(response)
      Provider::Gemini::ChatParser.new(response).parsed
    end
end
