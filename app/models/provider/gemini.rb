class Provider::Gemini < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Gemini::Error
  Error = Class.new(Provider::Error)

  MODELS = %w[gemini-2.5-flash gemini-2.5-pro gemini-2.5-flash-lite]

  def initialize(api_key)
    @client = ::Gemini.new(
      credentials: {
        service: "generative-language-api",
        api_key: api_key
      },
      options: { model: "gemini-2.5-flash", server_sent_events: true }
    )
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      prompt = build_categorization_prompt(transactions, user_categories)
      response = client.stream_generate_content({
        contents: { role: "user", parts: { text: prompt } }
      })

      parse_categorization_response(response, transactions)
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      prompt = build_merchant_detection_prompt(transactions, user_merchants)
      response = client.stream_generate_content({
        contents: { role: "user", parts: { text: prompt } }
      })

      parse_merchant_detection_response(response, transactions)
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results,
        instructions: instructions
      )

      collected_chunks = []

      # Update client model
      @client = ::Gemini.new(
        credentials: {
          service: "generative-language-api",
          api_key: @client.instance_variable_get(:@credentials)[:api_key]
        },
        options: { model: model, server_sent_events: streamer.present? }
      )

      if streamer.present?
        # Streaming response
        client.stream_generate_content(chat_config.build_request(prompt)) do |chunk, _raw|
          parsed_chunk = ChatStreamParser.new(chunk).parsed

          unless parsed_chunk.nil?
            streamer.call(parsed_chunk)
            collected_chunks << parsed_chunk
          end
        end

        # Find and return the response chunk
        response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
        response_chunk&.data
      else
        # Non-streaming response
        raw_response = client.stream_generate_content(chat_config.build_request(prompt))
        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client

    def build_categorization_prompt(transactions, user_categories)
      categories_list = user_categories.map { |c| "- #{c[:name]}" }.join("\n")
      transactions_list = transactions.map do |t|
        "ID: #{t[:id]}, Name: #{t[:name]}, Amount: #{t[:amount]}, Merchant: #{t[:merchant]}"
      end.join("\n")

      <<~PROMPT
        Categorize the following transactions into one of these categories:
        #{categories_list}

        Transactions:
        #{transactions_list}

        Return a JSON array with objects containing "transaction_id" and "category_name" fields.
      PROMPT
    end

    def build_merchant_detection_prompt(transactions, user_merchants)
      merchants_list = user_merchants.map { |m| "- #{m[:name]}" }.join("\n")
      transactions_list = transactions.map do |t|
        "ID: #{t[:id]}, Name: #{t[:name]}"
      end.join("\n")

      <<~PROMPT
        Detect the merchant business name and website for these transactions:
        #{transactions_list}

        Known merchants: #{merchants_list}

        Return a JSON array with objects containing "transaction_id", "business_name", and "business_url" fields.
      PROMPT
    end

    def parse_categorization_response(response, transactions)
      # Extract text from response and parse JSON
      text = extract_text_from_response(response)
      data = JSON.parse(text)

      data.map do |item|
        AutoCategorization.new(
          transaction_id: item["transaction_id"],
          category_name: item["category_name"]
        )
      end
    rescue JSON::ParserError => e
      raise Error, "Failed to parse categorization response: #{e.message}"
    end

    def parse_merchant_detection_response(response, transactions)
      text = extract_text_from_response(response)
      data = JSON.parse(text)

      data.map do |item|
        AutoDetectedMerchant.new(
          transaction_id: item["transaction_id"],
          business_name: item["business_name"],
          business_url: item["business_url"]
        )
      end
    rescue JSON::ParserError => e
      raise Error, "Failed to parse merchant detection response: #{e.message}"
    end

    def extract_text_from_response(response)
      response.dig("candidates", 0, "content", "parts", 0, "text") || ""
    end
end
