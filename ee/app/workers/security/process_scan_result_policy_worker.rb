# frozen_string_literal: true

module Security
  class ProcessScanResultPolicyWorker
    include ApplicationWorker

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once, including_scheduled: true

    data_consistency :always
    sidekiq_options retry: true
    feature_category :security_policy_management

    HISTOGRAM = :gitlab_security_policies_scan_result_process_duration_seconds

    def perform(project_id, configuration_id)
      measure(HISTOGRAM) do
        project = Project.find_by_id(project_id)
        configuration = Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id)
        break unless project && configuration

        sync_policies(project, configuration)

        Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService
          .new(project: project, policy_configuration: configuration)
          .execute
      end
    end

    private

    def sync_policies(project, configuration)
      configuration.delete_scan_finding_rules_for_project(project.id)
      configuration.delete_software_license_policies_for_project(project)
      configuration.delete_policy_violations_for_project(project)
      configuration.delete_scan_result_policy_reads_for_project(project)

      configuration.applicable_scan_result_policies_with_real_index(project) do |policy, policy_idx, real_policy_idx|
        Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService.new(
          project: project,
          policy_configuration: configuration,
          policy: policy,
          policy_index: policy_idx,
          real_policy_index: real_policy_idx
        ).execute
      end
    end

    delegate :measure, to: Security::SecurityOrchestrationPolicies::ObserveHistogramsService
  end
end
