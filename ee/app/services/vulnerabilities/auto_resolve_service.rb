# frozen_string_literal: true

module Vulnerabilities
  class AutoResolveService
    MAX_BATCH = 100

    def initialize(project, vulnerability_ids, security_policy_name)
      @project = project
      @vulnerability_ids = vulnerability_ids
      @security_policy_name = security_policy_name
    end

    def execute
      return error_response unless can_create_state_transitions?

      vulnerability_ids.each_slice(MAX_BATCH).each do |ids|
        resolve(Vulnerability.id_in(ids))
      end
      refresh_statistics

      ServiceResponse.success
    rescue ActiveRecord::ActiveRecordError
      error_response
    end

    private

    attr_reader :project, :vulnerability_ids, :security_policy_name

    def resolve(vulnerabilities)
      # rubocop:disable CodeReuse/ActiveRecord -- context specific
      # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- Caller limits to 100 records
      vulnerability_attrs = vulnerabilities.pluck(:id, :state)
      # rubocop:enable CodeReuse/ActiveRecord
      # rubocop:enable Database/AvoidUsingPluckWithoutLimit

      return if vulnerability_attrs.empty?

      state_transitions = transition_attributes_for(vulnerability_attrs)
      system_notes = system_note_attributes_for(vulnerability_attrs)

      Vulnerability.transaction do
        Vulnerabilities::StateTransition.insert_all!(state_transitions)

        vulnerabilities.update_all(
          state: :resolved,
          auto_resolved: true,
          resolved_by_id: user.id,
          resolved_at: now,
          updated_at: now
        )
      end
      Note.insert_all!(system_notes)
    end

    def transition_attributes_for(attrs)
      attrs.map do |id, state|
        {
          vulnerability_id: id,
          from_state: state,
          to_state: :resolved,
          author_id: user.id,
          comment: comment,
          created_at: now,
          updated_at: now
        }
      end
    end

    def system_note_attributes_for(attrs)
      attrs.map do |id, _|
        {
          noteable_type: "Vulnerability",
          noteable_id: id,
          project_id: project.id,
          namespace_id: project.project_namespace_id,
          system: true,
          note: ::SystemNotes::VulnerabilitiesService.formatted_note(
            'changed',
            :resolved,
            nil,
            comment
          ),
          author_id: user.id,
          created_at: now,
          updated_at: now
        }
      end
    end

    def comment
      _("Auto-resolved by vulnerability management policy") + " #{security_policy_name}"
    end

    def user
      @user ||= project.security_policy_bot
    end

    def refresh_statistics
      Vulnerabilities::Statistics::AdjustmentWorker.perform_async([project.id])
    end

    def can_create_state_transitions?
      Ability.allowed?(user, :create_vulnerability_state_transition, project)
    end

    # We use this for setting the created_at and updated_at timestamps
    # for the various records created by this service.
    # The time is memoized on the first call to this method so all of the
    # created records will have the same timestamps.
    def now
      @now ||= Time.current.utc
    end

    def error_response
      ServiceResponse.error(message: "Could not resolve vulnerabilities")
    end
  end
end
