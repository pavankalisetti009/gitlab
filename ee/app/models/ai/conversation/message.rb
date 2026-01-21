# frozen_string_literal: true

module Ai
  module Conversation
    class Message < ApplicationRecord
      include Gitlab::Utils::StrongMemoize

      self.table_name = :ai_conversation_messages

      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :thread, class_name: 'Ai::Conversation::Thread', inverse_of: :messages

      delegate :user, to: :thread, allow_nil: true

      validates :content, :role, :thread_id, presence: true
      validates :extras, json_schema: { filename: "ai_conversation_message_extras" },
        if: -> { new_record? || extras_changed? }

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

      enum :role, { user: 1, assistant: 2 }

      before_validation :truncate_referer_url, if: -> { referer_url.present? }
      before_create :populate_organization

      alias_attribute :request_id, :request_xid
      alias_attribute :timestamp, :created_at
      attr_accessor :chunk_id

      def self.find_for_user!(xid, user)
        for_id(xid).for_user(user).first!
      end

      def self.recent(limit)
        order(id: :desc).limit(limit).reverse
      end

      def ai_action
        'chat'
      end

      def conversation_reset?
        content == Gitlab::Llm::ChatMessage::RESET_MESSAGE
      end

      def clear_history?
        content == Gitlab::Llm::ChatMessage::CLEAR_HISTORY_MESSAGE ||
          content == Gitlab::Llm::ChatMessage::NEW_MESSAGE
      end

      def question?
        user? && !conversation_reset? && !clear_history?
      end

      def extras
        extras_hash = self[:extras] || {}

        begin
          extras_hash = ::Gitlab::Json.parse(extras_hash) if extras_hash.is_a?(String)
        rescue JSON::ParserError
          extras_hash = {}
        end

        extras_hash['has_feedback'] = has_feedback?
        extras_hash
      end

      def error_details
        error_data = self[:error_details] || []

        begin
          error_data = ::Gitlab::Json.parse(error_data) if error_data.is_a?(String)

          # Handle new structured format
          return error_data['messages'] || [] if error_data.is_a?(Hash)

          # Handle old format (array)
          return error_data if error_data.is_a?(Array)
        rescue JSON::ParserError
          return []
        end

        []
      end

      def error_code
        error_data = self[:error_details]
        return if error_data.blank?

        begin
          error_data = ::Gitlab::Json.parse(error_data) if error_data.is_a?(String)

          # New structured format
          return error_data['code'] if error_data.is_a?(Hash) && error_data['code'].present?

          # Old format: extract from markdown link [G3001](url)
          if error_data.is_a?(Array) && error_data.first.is_a?(String)
            match = error_data.first.match(/\[([A-Z]\d+)\]\(/)
            return match[1] if match
          end
        rescue JSON::ParserError
          # Return nil on error
        end

        nil
      end

      private

      def populate_organization
        self.organization ||= thread.organization
      end

      def truncate_referer_url
        self.referer_url = referer_url.truncate(255, omission: '')
      end
    end
  end
end
