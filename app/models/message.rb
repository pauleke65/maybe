class Message < ApplicationRecord
  belongs_to :chat
  has_many :tool_calls, dependent: :destroy

  enum :status, {
    pending: "pending",
    complete: "complete",
    failed: "failed"
  }

  validates :content, presence: true

  after_create_commit -> { broadcast_append_to chat, target: "messages" }, if: :broadcast?
  after_update_commit -> { broadcast_update_to chat }, if: :broadcast?

  scope :ordered, -> { order(created_at: :asc) }

  class << self
    def supported_ai_models
      registry = Provider::Registry.for_concept(:llm)
      registry.providers.compact.flat_map do |provider|
        provider.class::MODELS
      end
    end
  end

  private
    def broadcast?
      true
    end
end
