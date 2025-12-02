# frozen_string_literal: true

module Vulnerabilities
  class AutoDismissService < BaseAutoStateTransitionService
    BATCH_SIZE = 1000
    AUTO_DISMISS_LIMIT = 1000

    def initialize(pipeline, vulnerability_ids)
      super
      @dismissed_count = 0
    end

    def execute
      return success unless Feature.enabled?(:auto_dismiss_vulnerability_policies, project)
      return success unless project.licensed_feature_available?(:security_orchestration_policies)
      return success if policies.blank?

      super do
        vulnerability_reads.each_batch(of: BATCH_SIZE) { |batch| process_batch(batch) }
        dismissed_count
      end
    end

    private

    attr_accessor :dismissed_count

    def process_batch(batch)
      budget = AUTO_DISMISS_LIMIT - dismissed_count
      return if budget <= 0

      rules_by_vulnerability = batch.index_with do |read|
        rules.find { |rule| rule.match?(read.vulnerability) }
      end.compact

      vulnerabilities_to_dismiss = rules_by_vulnerability.keys.first(budget)

      perform_state_transition(vulnerabilities_to_dismiss, rules_by_vulnerability)
      @dismissed_count += vulnerabilities_to_dismiss.size
    end

    def vulnerability_reads
      super.with_findings_scanner_and_identifiers
    end

    def policies
      project
        .vulnerability_management_policies
        .auto_dismiss_policies.including_rules
    end
    strong_memoize_attr :policies

    def rules
      policies
        .flat_map(&:vulnerability_management_policy_rules)
        .select(&:type_detected?)
    end
    strong_memoize_attr :rules

    def update_transaction(vulnerabilities_to_dismiss, rules_by_vulnerability)
      Vulnerability.transaction do
        Vulnerabilities::StateTransition.insert_all!(
          state_transition_attrs(vulnerabilities_to_dismiss, rules_by_vulnerability)
        )

        vulnerabilities_to_update = Vulnerability.id_in(vulnerabilities_to_dismiss.map(&:vulnerability_id))
        vulnerabilities_to_update.update_all(
          state: :dismissed,
          dismissed_by_id: user.id,
          dismissed_at: now,
          updated_at: now,
          auto_resolved: false
        )

        Vulnerability.current_transaction.after_commit do
          Vulnerabilities::BulkEsOperationService.new(vulnerabilities_to_update).execute(&:itself)
          trigger_webhook_events(vulnerabilities_to_update)
        end

        Vulnerabilities::Reads::UpsertService.new(vulnerabilities_to_update,
          { state: :dismissed, dismissal_reason: dismissal_reason_enum_value },
          projects: project
        ).execute
      end
    end

    def internal_event_name
      'auto_dismiss_vulnerability_in_project_after_pipeline_run_if_policy_is_set'
    end

    def target_state
      :dismissed
    end

    def formatted_system_note(vulnerability, rules_by_vulnerability_map)
      ::SystemNotes::VulnerabilitiesService.formatted_note(
        'changed',
        :dismissed,
        dismissal_reason.to_s.titleize,
        comment(vulnerability, rules_by_vulnerability_map)
      )
    end

    def note_metadata_action
      'vulnerability_dismissed'
    end

    def comment(vulnerability, rules_by_vulnerability)
      rule = rules_by_vulnerability[vulnerability]
      format(
        _("Auto-dismissed by the vulnerability management policy named '%{policy_name}' " \
          "as the vulnerability matched the policy criteria in pipeline %{pipeline_link}."),
        policy_name: rule.security_policy.name,
        pipeline_link: pipeline_link
      )
    end

    def dismissal_reason
      # Get the dismissal reason from the first policy's action
      # All auto-dismiss policies should have the same dismissal reason
      policies.first.dismissal_reason
    end
    strong_memoize_attr :dismissal_reason

    def dismissal_reason_enum_value
      Vulnerabilities::DismissalReasonEnum.values[dismissal_reason.to_sym]
    end
    strong_memoize_attr :dismissal_reason_enum_value

    def base_error_message
      'Could not dismiss vulnerabilities'
    end

    def state_transition_base_attrs(_vulnerability)
      { dismissal_reason: dismissal_reason_enum_value }
    end
  end
end
