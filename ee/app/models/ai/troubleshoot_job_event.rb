# frozen_string_literal: true

module Ai
  class TroubleshootJobEvent < ApplicationRecord
    include PartitionedTable
    include UsageEvent

    self.table_name = "ai_troubleshoot_job_events"
    self.clickhouse_table_name = "troubleshoot_job_events"
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
    before_validation :fill_payload

    def self.permitted_attributes
      super + %w[project_id merge_request_id job]
    end

    def store_to_pg
      return false unless valid?

      Ai::UsageEventWriteBuffer.add(self.class.name, attributes.compact)
    end

    def to_clickhouse_csv_row
      super.merge({
        user_id: user_id,
        project_id: project_id,
        job_id: job_id,
        pipeline_id: payload['pipeline_id'],
        merge_request_id: payload['merge_request_id']
      })
    end

    private

    def fill_payload
      payload['pipeline_id'] ||= job&.pipeline_id
      payload['merge_request_id'] ||= job&.pipeline&.merge_request_id
    end

    def populate_sharding_key
      self.project_id ||= job&.project_id
    end

    def validate_recent_timestamp
      return unless timestamp && timestamp < self.class.partitioning_strategy.retain_for.ago

      errors.add(:timestamp, _('must be 3 months old at the most'))
    end
  end
end
