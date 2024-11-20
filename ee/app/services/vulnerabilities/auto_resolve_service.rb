# frozen_string_literal: true

module Vulnerabilities
  class AutoResolveService
    include Gitlab::Utils::StrongMemoize

    MAX_BATCH = 100

    def initialize(project, vulnerability_ids)
      @project = project
      @vulnerabilities = Vulnerability.id_in(vulnerability_ids.first(MAX_BATCH))
    end

    def execute
      return ServiceResponse.success if policies.blank?
      return error_response unless can_create_state_transitions?

      resolve_vulnerabilities
      refresh_statistics

      ServiceResponse.success
    rescue ActiveRecord::ActiveRecordError
      error_response
    end

    private

    attr_reader :project, :vulnerabilities

    def vulnerabilities_to_resolve
      policies_by_vulnerability.keys
    end

    def policies_by_vulnerability
      policies.each_with_object({}) do |policy, memo|
        vulnerabilities.each do |vulnerability|
          if policy.match?(vulnerability)
            memo[vulnerability] ||= []
            memo[vulnerability].push(policy)
          end
        end
      end
    end
    strong_memoize_attr :policies_by_vulnerability

    def policies
      # TODO: This should only include policies that have a `no_longer_detected` rule
      # and an `auto_resolve` action
      project.security_policies.type_vulnerability_management_policy
    end

    def resolve_vulnerabilities
      return if vulnerabilities_to_resolve.empty?

      Vulnerability.transaction do
        Vulnerabilities::StateTransition.insert_all!(state_transition_attrs)

        Vulnerability.id_in(vulnerabilities_to_resolve.map(&:id)).update_all(
          state: :resolved,
          auto_resolved: true,
          resolved_by_id: user.id,
          resolved_at: now,
          updated_at: now
        )
      end
      Note.insert_all!(system_note_attrs)
    end

    def state_transition_attrs
      vulnerabilities_to_resolve.map do |vulnerability|
        {
          vulnerability_id: vulnerability.id,
          from_state: vulnerability.state,
          to_state: :resolved,
          author_id: user.id,
          comment: comment(vulnerability),
          created_at: now,
          updated_at: now
        }
      end
    end

    def system_note_attrs
      vulnerabilities_to_resolve.map do |vulnerability|
        {
          noteable_type: "Vulnerability",
          noteable_id: vulnerability.id,
          project_id: project.id,
          namespace_id: project.project_namespace_id,
          system: true,
          note: ::SystemNotes::VulnerabilitiesService.formatted_note(
            'changed',
            :resolved,
            nil,
            comment(vulnerability)
          ),
          author_id: user.id,
          created_at: now,
          updated_at: now
        }
      end
    end

    def comment(vulnerability)
      policy_names = policies_by_vulnerability[vulnerability].map(&:name)
      _("Auto-resolved by vulnerability management policy") + " #{policy_names.join(', ')}"
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
