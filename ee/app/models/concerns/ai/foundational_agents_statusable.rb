# frozen_string_literal: true

module Ai
  module FoundationalAgentsStatusable
    extend ActiveSupport::Concern

    included do
      def foundational_agents_statuses=(values)
        return unless values

        self.class.transaction do
          foundational_agents_status_records.delete_all(:delete_all)

          values.each do |status|
            record = foundational_agents_status_records.build(status)

            errors.add(:foundational_agents_statuses, record.errors.full_messages.join(', ')) unless record.save
          end

          raise ActiveRecord::Rollback if errors.any?
        end
      end

      def foundational_agents_statuses
        statuses = foundational_agents_status_records.index_by(&:reference)

        ::Ai::FoundationalChatAgent.except_duo_chat_agent.map do |agent|
          status_record = statuses[agent.reference]

          {
            reference: agent.reference,
            name: agent.name,
            description: agent.description,
            enabled: status_record&.enabled
          }
        end
      end

      def enabled_foundational_agents
        statuses = foundational_agents_status_records.index_by(&:reference)

        ::Ai::FoundationalChatAgent.all.select do |agent|
          if statuses.has_key?(agent.reference)
            statuses[agent.reference].enabled
          else
            agent.duo_chat? || foundational_agents_default_enabled
          end
        end
      end
    end
  end
end
