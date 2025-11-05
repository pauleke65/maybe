class Provider::Gemini::ChatConfig
  def initialize(functions: [], function_results: [], instructions: nil)
    @functions = functions
    @function_results = function_results
    @instructions = instructions
  end

  def tools
    return nil if functions.empty?

    {
      function_declarations: functions.map do |fn|
        {
          name: fn[:name],
          description: fn[:description],
          parameters: fn[:params_schema]
        }
      end
    }
  end

  def build_request(prompt)
    contents = []

    # Add system instructions if present
    system_instruction = if instructions.present?
      {
        role: "user",
        parts: { text: instructions }
      }
    end

    # Add user prompt
    contents << {
      role: "user",
      parts: { text: prompt }
    }

    # Add function results if present
    function_results.each do |fn_result|
      contents << {
        role: "function",
        parts: {
          functionResponse: {
            name: fn_result[:name],
            response: fn_result[:output]
          }
        }
      }
    end

    request = { contents: contents }
    request[:system_instruction] = system_instruction if system_instruction
    request[:tools] = [ tools ] if tools

    request
  end

  private
    attr_reader :functions, :function_results, :instructions
end
