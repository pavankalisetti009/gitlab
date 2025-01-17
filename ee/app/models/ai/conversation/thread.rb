# frozen_string_literal: true

module Ai
  module Conversation
    class Thread < ApplicationRecord
      include EachBatch

      self.table_name = :ai_conversation_threads

      has_many :messages, class_name: 'Ai::Conversation::Message', inverse_of: :thread
      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :user

      validates :conversation_type, :user_id, presence: true

      scope :expired, -> { where(last_updated_at: ...30.days.ago) }

      enum conversation_type: { duo_chat: 1 }

      before_create :populate_organization

      private

      def populate_organization
        self.organization_id ||= user.organizations.first&.id ||
          Organizations::Organization.first.id
      end
    end
  end
end
