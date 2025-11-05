class AssistantMessage < Message
  validates :ai_model, presence: true, inclusion: {
    in: -> (_) { Message.supported_ai_models },
    message: "%{value} is not a supported AI model"
  }

  def role
    "assistant"
  end

  def append_text!(text)
    self.content += text
    save!
  end
end
