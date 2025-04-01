# frozen_string_literal: true

module Security
  class AnalyzerProjectStatus < ::Gitlab::Database::SecApplicationRecord
    self.table_name = 'analyzer_project_statuses'

    belongs_to :project

    enum analyzer_type: Enums::Security.analyzer_types
    enum status: {
      not_configured: 0,
      success: 1,
      failed: 2
    }

    validates :analyzer_type, presence: true
    validates :status, presence: true
    validates :last_call, presence: true
    validates :traversal_ids, presence: true
  end
end
