# frozen_string_literal: true

module Ai
  module Conversation
    class Thread < ApplicationRecord
      self.table_name = :ai_conversation_threads

      has_many :messages, class_name: 'Ai::Conversation::Message'
      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :user

      validates :conversation_type, :user_id, presence: true

      scope :expired, -> { where(last_updated_at: ...30.days.ago) }

      enum conversation_type: { duo_chat: 1 }

      before_validation :populate_organization_id

      private

      def populate_organization_id
        return if organization_id

        organization_id = user&.namespace&.organization_id ||
          Organizations::Organization::DEFAULT_ORGANIZATION_ID

        self.organization_id = organization_id
      end
    end
  end
end
