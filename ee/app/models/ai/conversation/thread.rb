# frozen_string_literal: true

module Ai
  module Conversation
    class Thread < ApplicationRecord
      include EachBatch

      EXPIRATION_PERIOD = 30.days

      self.table_name = :ai_conversation_threads

      has_many :messages, class_name: 'Ai::Conversation::Message', inverse_of: :thread
      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :user

      validates :conversation_type, :user_id, presence: true

      scope :expired, -> { where(last_updated_at: ...EXPIRATION_PERIOD.ago) }
      scope :for_conversation_type, ->(conversation_type) { where(conversation_type: conversation_type) }
      scope :ordered, -> { order(last_updated_at: :desc) }

      enum conversation_type: {
        duo_chat_legacy: 1,
        duo_code_review: 2,
        duo_quick_chat: 3,
        duo_chat: 4
      }

      before_create :populate_organization

      def to_new_thread!
        self.class.create!(
          attributes.slice(*%w[user_id organization_id conversation_type])
        )
      end

      def dup_as_duo_chat_thread!
        transaction do
          new_thread = self.class.new(attributes.except('id'))
          new_thread.conversation_type = :duo_chat
          new_thread.save!
          messages.recent(::Gitlab::Llm::ChatStorage::Postgresql::MAX_MESSAGES).each do |message|
            new_thread.messages.create(message.attributes.except('id', 'thread_id'))
          end
          new_thread
        end
      end

      private

      def populate_organization
        self.organization_id ||= user.organizations.first&.id ||
          Organizations::Organization.first.id
      end
    end
  end
end
