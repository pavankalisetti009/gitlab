# frozen_string_literal: true

module Issues
  class CopyTimelogsWorker
    include ApplicationWorker

    data_consistency :sticky
    deduplicate :until_executed
    idempotent!
    feature_category :team_planning

    BATCH_SIZE = 100
    def perform(from_issue_id, to_issue_id)
      Gitlab::AppLogger.info("Copying timelogs from issue #{from_issue_id} to issue #{to_issue_id}")

      from_issue = Issue.find_by_id(from_issue_id)
      to_issue = Issue.find_by_id(to_issue_id)
      return if from_issue.nil? || to_issue.nil? || from_issue.timelogs.empty?

      reset_attributes = { project_id: to_issue.project_id, issue_id: to_issue.id }
      ApplicationRecord.transaction do
        from_issue.timelogs.each_slice(BATCH_SIZE) do |timelogs|
          new_timelogs_attributes = timelogs.map do |timelog|
            timelog.attributes.except('id').merge(reset_attributes)
          end

          Timelog.insert_all!(new_timelogs_attributes)
        end
      end
    end
  end
end
