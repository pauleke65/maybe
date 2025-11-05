module ChatsHelper
  def chat_frame
    :sidebar_chat
  end

  def chat_view_path(chat)
    return new_chat_path if params[:chat_view] == "new"
    return chats_path if chat.nil? || params[:chat_view] == "all"

    chat.persisted? ? chat_path(chat) : new_chat_path
  end

  def ai_model_options
    Message.supported_ai_models.map do |model|
      [ format_ai_model_name(model), model ]
    end
  end

  def format_ai_model_name(model)
    case model
    when "gpt-4.1"
      "GPT-4.1 (OpenAI)"
    when "gemini-2.5-flash"
      "Gemini 2.5 Flash (Google)"
    when "gemini-2.5-pro"
      "Gemini 2.5 Pro (Google)"
    when "gemini-2.5-flash-lite"
      "Gemini 2.5 Flash Lite (Google)"
    else
      model.titleize
    end
  end
end
