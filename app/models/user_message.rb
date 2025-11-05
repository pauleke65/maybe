class UserMessage < Message
  validates :ai_model, presence: true, inclusion: {
    in: -> (_) { Message.supported_ai_models },
    message: "%{value} is not a supported AI model"
  }

  after_create_commit :request_response_later

  def role
    "user"
  end

  def request_response_later
    chat.ask_assistant_later(self)
  end

  def request_response
    chat.ask_assistant(self)
  end
end
