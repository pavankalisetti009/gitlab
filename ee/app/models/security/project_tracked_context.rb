# frozen_string_literal: true

# security_project_tracked_contexts exists to track contexts related to a project to which
# vulnerability information may related and or actively tracked from. In the initial scope
# this is limited to git refs in the traditional static analysis sense, but will likely expand to
# accomodate contexts like job artifacts, logs, packages, containers and more
#
# A record existing in this table does not directly imply tracking, only that the context exists
# and may have vulnerability information related to it. For tracking to be actively enabled against
# that context, the `tracking` field should be set to true

module Security
  class ProjectTrackedContext < ::SecApplicationRecord
    self.table_name = 'security_project_tracked_contexts'

    STATES = { untracked: 1, tracked: 2, archiving: 0, deleting: -1 }.freeze

    belongs_to :project, inverse_of: :security_project_tracked_contexts

    has_many :sbom_occurrence_refs,
      class_name: 'Sbom::OccurrenceRef',
      foreign_key: 'security_project_tracked_context_id',
      inverse_of: :tracked_context

    validates :context_name, presence: true, length: { maximum: 1024 }
    validates :context_type, presence: true
    validates :context_name, uniqueness: { scope: [:project_id, :context_type] }
    validate :tracked_refs_limit
    validate :default_ref_cannot_be_untracked, if: :is_default?

    enum :context_type, {
      branch: 1,
      tag: 2
    }

    state_machine :state, initial: :untracked do
      STATES.each do |state_name, value|
        state state_name, value: value
      end

      event :untrack do
        transition tracked: :untracked
      end

      event :track do
        transition untracked: :tracked
      end

      event :archive do
        transition [:untracked, :tracked] => :archiving
      end

      event :remove do
        transition any => :deleting
      end
    end

    scope :for_project, ->(project_id) { where(project_id: project_id) }
    scope :default_refs, -> { where(is_default: true) }

    STATES.each do |state_name, value|
      scope state_name, -> { where(state: value) }
    end

    # Maximum number of tracked refs per project (default branch + 15 additional refs)
    MAX_TRACKED_REFS_PER_PROJECT = 16

    private

    def tracked_refs_limit
      return unless tracked?

      tracked_query = self.class.for_project(project_id).tracked
      tracked_query = tracked_query.where.not(id: id) if persisted?

      return unless tracked_query.limit(MAX_TRACKED_REFS_PER_PROJECT).count >= MAX_TRACKED_REFS_PER_PROJECT

      errors.add(:state, "cannot exceed #{MAX_TRACKED_REFS_PER_PROJECT} tracked refs per project")
    end

    def default_ref_cannot_be_untracked
      return unless is_default? && !tracked?

      errors.add(:state, 'default ref must be tracked')
    end
  end
end
