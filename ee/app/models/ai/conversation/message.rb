# frozen_string_literal: true

module Ai
  module Conversation
    class Message < ApplicationRecord
      self.table_name = :ai_conversation_messages

      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :thread, class_name: 'Ai::Conversation::Thread'

      validates :content, :role, :thread_id, presence: true

      scope :for_thread, ->(thread) { where(thread: thread).order(created_at: :asc) }
      # This message_xid is a secure random ID that is generated in runtime.
      # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/llm/ai_message.rb#L47
      scope :for_message_xid, ->(message_xid) { where(message_xid: message_xid) }

      enum role: { user: 1, assistant: 2 }

      before_validation :populate_organization_id

      private

      def populate_organization_id
        return if organization_id

        organization_id = thread&.user&.namespace&.organization_id ||
          Organizations::Organization::DEFAULT_ORGANIZATION_ID

        self.organization_id = organization_id
      end
    end
  end
end
