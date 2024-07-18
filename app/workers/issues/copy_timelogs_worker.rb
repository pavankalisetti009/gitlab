# frozen_string_literal: true

module Issues
  class CopyTimelogsWorker
    include ApplicationWorker

    data_consistency :delayed
    idempotent!
    feature_category :team_planning

    def perform(from_issue_id, to_issue_id)
      Gitlab::AppLogger.info("Copying timelogs from issue #{from_issue_id} to issue #{to_issue_id}")

      from_issue = Issue.find_by_id(from_issue_id)
      to_issue = Issue.find_by_id(to_issue_id)
      return if from_issue.nil? || to_issue.nil? || from_issue.timelogs.empty? || to_issue.timelogs.any?

      new_attributes = { id: nil, project_id: to_issue.project_id, issue_id: to_issue.id }
      new_timelogs = from_issue.timelogs.dup

      ApplicationRecord.transaction do
        new_timelogs.each do |timelog|
          timelog.assign_attributes(new_attributes)
          Timelog.create!(timelog.attributes)
        end
      end
    end
  end
end
