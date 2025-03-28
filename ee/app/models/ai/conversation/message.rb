# frozen_string_literal: true

module Ai
  module Conversation
    class Message < ApplicationRecord
      self.table_name = :ai_conversation_messages

      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :thread, class_name: 'Ai::Conversation::Thread', inverse_of: :messages

      validates :content, :role, :thread_id, presence: true

      scope :for_thread, ->(thread) { where(thread: thread) }
      scope :for_user, ->(user) { joins(:thread).where(ai_conversation_threads: { user_id: user.id }) }
      # id can either be an ActiveRecord ID, or a secure random ID that is generated in runtime.
      # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/llm/ai_message.rb#L47
      scope :for_id, ->(id) do
        if id.is_a?(String) && id.length == 36
          where(message_xid: id)
        else
          where(id: id)
        end
      end
      scope :ordered, -> { order(id: :asc) }

      enum role: { user: 1, assistant: 2 }

      before_create :populate_organization

      def self.find_for_user!(xid, user)
        for_id(xid).for_user(user).first!
      end

      def self.recent(limit)
        order(id: :desc).limit(limit).reverse
      end

      private

      def populate_organization
        self.organization ||= thread.organization
      end
    end
  end
end
