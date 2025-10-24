# frozen_string_literal: true

module Sbom
  class OccurrenceRef < ::SecApplicationRecord
    include EachBatch

    self.table_name = 'sbom_occurrence_refs'

    belongs_to :project,
      inverse_of: :sbom_occurrence_refs

    belongs_to :occurrence,
      class_name: 'Sbom::Occurrence',
      foreign_key: :sbom_occurrence_id,
      inverse_of: :occurrence_refs

    belongs_to :tracked_context,
      class_name: 'Security::ProjectTrackedContext',
      foreign_key: :security_project_tracked_context_id,
      inverse_of: :sbom_occurrence_refs

    belongs_to :pipeline,
      class_name: 'Ci::Pipeline',
      inverse_of: :sbom_occurrence_refs,
      optional: true

    validates :commit_sha, presence: true
    validates :sbom_occurrence_id, presence: true
    validates :security_project_tracked_context_id, presence: true
    validates :project_id, presence: true

    scope :by_occurrence, ->(occurrence_id) { where(sbom_occurrence_id: occurrence_id) }
    scope :by_tracked_context, ->(context_id) { where(security_project_tracked_context_id: context_id) }
    scope :by_project, ->(project_id) { where(project_id: project_id) }
  end
end
