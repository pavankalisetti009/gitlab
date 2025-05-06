# frozen_string_literal: true

module Security
  class AnalyzerNamespaceStatus < ::SecApplicationRecord
    self.table_name = 'analyzer_namespace_statuses'

    belongs_to :group, foreign_key: :namespace_id, inverse_of: :analyzer_group_statuses
    belongs_to :namespace

    enum analyzer_type: Enums::Security.analyzer_types

    validates :success, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :failure, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :analyzer_type, presence: true
    validates :traversal_ids, presence: true
  end
end
