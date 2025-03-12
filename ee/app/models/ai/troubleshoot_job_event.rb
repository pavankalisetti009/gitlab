# frozen_string_literal: true

module Ai
  class TroubleshootJobEvent < ApplicationRecord
    include PartitionedTable
    include UsageEvent

    self.table_name = "ai_troubleshoot_job_events"
    self.primary_key = :id

    partitioned_by :timestamp, strategy: :monthly, retain_for: 3.months

    attribute :timestamp, :datetime, default: -> { DateTime.current }

    enum event: { troubleshoot_job: 1 }

    belongs_to :user, optional: false
    belongs_to :project, optional: false
    belongs_to :job, class_name: 'Ci::Build', optional: false

    validates :timestamp, presence: true
    validates :payload, json_schema: { filename: "ai_troubleshoot_job_event" }, allow_blank: true
    validate :validate_recent_timestamp, on: :create

    before_validation :populate_sharding_key

    def store_to_pg
      return false unless valid?

      Ai::UsageEventWriteBuffer.add(self.class.name, attributes.compact)
    end

    private

    def populate_sharding_key
      self.project_id ||= job&.project_id
    end

    def validate_recent_timestamp
      return unless timestamp && timestamp < self.class.partitioning_strategy.retain_for.ago

      errors.add(:timestamp, _('must be 3 months old at the most'))
    end
  end
end
