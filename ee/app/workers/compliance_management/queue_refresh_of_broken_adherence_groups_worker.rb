# frozen_string_literal: true

module ComplianceManagement
  class QueueRefreshOfBrokenAdherenceGroupsWorker
    include ApplicationWorker
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- service does not require context

    TimeoutError = Class.new(StandardError)

    version 1
    urgency :throttled
    data_consistency :sticky
    feature_category :compliance_management
    sidekiq_options retry: false
    idempotent!

    # This cron worker is executed at an interval of 20 minutes.
    # Maximum run time is kept as 4 minutes to avoid breaching maximum allowed execution latency of 5 minutes.
    MAX_RUN_TIME = 4.minutes
    BATCH_SIZE = 100

    def perform
      return unless Feature.enabled?(:ff_compliance_repair_adherences) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- instance wide repair

      start_time
      admin_bot_id = Users::Internal.admin_bot.id

      find_broken_adherences_in_batches do |group_ids|
        raise TimeoutError if over_time?

        group_ids.uniq.each do |group_id|
          log_extra_metadata_on_done :group_id, group_id
          ComplianceManagement::Standards::RefreshWorker
            .perform_async({ 'group_id' => group_id, 'user_id' => admin_bot_id })
        end
      end
    rescue TimeoutError
      # cron will reschedule it again soon(< 16 min), just exit
      log_extra_metadata_on_done :timeout_reached, run_time
    end

    private

    # rubocop:disable CodeReuse/ActiveRecord -- One time fix for broken records after incident
    def find_broken_adherences_in_batches
      relation = ::Projects::ComplianceStandards::Adherence
        .distinct('projects.namespace_id')
        .joins(:project)
        .where('project_compliance_standards_adherence.namespace_id != projects.namespace_id')
        .select('projects.namespace_id')

      relation.each_batch(of: BATCH_SIZE) do |batch|
        yield batch.pluck('projects.namespace_id')
      end
    end
    # rubocop:enable CodeReuse/ActiveRecord

    def start_time
      @start_time ||= ::Gitlab::Metrics::System.monotonic_time
    end

    def run_time
      ::Gitlab::Metrics::System.monotonic_time - start_time
    end

    def over_time?
      run_time > MAX_RUN_TIME
    end
  end
end
