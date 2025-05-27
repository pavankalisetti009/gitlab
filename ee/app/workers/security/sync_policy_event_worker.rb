# frozen_string_literal: true

module Security
  class SyncPolicyEventWorker
    include Gitlab::EventStore::Subscriber
    include Gitlab::Utils::StrongMemoize

    data_consistency :always
    deduplicate :until_executing
    idempotent!

    feature_category :security_policy_management

    # We need to add a delay for batch of projects for groups with
    # a huge number of projects to reduce the pressure on sidekiq.
    PROJECTS_BATCH_SYNC_DELAY = 10.seconds
    SYNC_SERVICE_DELAY_INTERVAL = 1.minute

    def handle_event(event)
      case event
      when ::Repositories::ProtectedBranchCreatedEvent, ::Repositories::ProtectedBranchDestroyedEvent
        sync_rules_for_protected_branch_event(event)
      when ::Repositories::DefaultBranchChangedEvent
        sync_rules_for_default_branch_changed_event(event)
      when ::Projects::ComplianceFrameworkChangedEvent
        sync_rules_for_compliance_framework_changed_event(event)
      else
        raise ArgumentError, "Unknown event: #{event.class}"
      end
    end

    private

    def sync_rules_for_default_branch_changed_event(event)
      return if event.data[:container_type] != 'Project'

      project = Project.find_by_id(event.data[:container_id])

      return unless project
      return unless project.licensed_feature_available?(:security_orchestration_policies)
      return unless use_approval_policy_rules_for_approval_rules(project)

      sync_rules_for_project_from_read_model(project, event)
    end

    def sync_rules_for_protected_branch_event(event)
      project_or_group = parent(event)

      return unless project_or_group
      return unless project_or_group.licensed_feature_available?(:security_orchestration_policies)

      project_or_group.all_security_orchestration_policy_configurations.each do |configuration|
        if project_or_group.is_a?(Group)
          sync_rules_for_group(configuration, project_or_group, event)
        else
          sync_rules_for_project(configuration, project_or_group, event, SYNC_SERVICE_DELAY_INTERVAL)
        end
      end
    end

    def sync_rules_for_compliance_framework_changed_event(event)
      project = Project.find_by_id(event.data[:project_id])
      framework = ComplianceManagement::Framework.find_by_id(event.data[:compliance_framework_id])
      return unless project && framework

      policy_configuration_ids = project.all_security_orchestration_policy_configuration_ids
      return unless policy_configuration_ids.any?

      framework
        .security_orchestration_policy_configurations
        .with_security_policies.id_in(policy_configuration_ids)
        .find_each do |config|
          Security::ProcessScanResultPolicyWorker.perform_async(project.id, config.id)

          config.security_policies.undeleted.pluck_primary_key.each do |security_policy_id|
            sync_project_policy(project, security_policy_id, event)
          end
        end
    end

    def sync_rules_for_group(configuration, group, event)
      delay = 0
      group.all_project_ids.each_batch do |projects|
        projects.each do |project|
          sync_rules_for_project(configuration, project, event, delay)
        end

        delay += PROJECTS_BATCH_SYNC_DELAY
      end
    end

    def sync_rules_for_project(configuration, project, event, delay)
      if use_approval_policy_rules_for_approval_rules(project)
        sync_rules_for_project_from_read_model(project, event)
      else
        sync_rules_for_project_from_yaml(configuration, project, delay)
      end
    end

    def sync_rules_for_project_from_yaml(configuration, project, delay)
      Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService
        .new(configuration)
        .execute(project.id, { delay: delay })
    end

    def sync_rules_for_project_from_read_model(project, event)
      # A project can have multiple inherited security policy project. But we want to
      # sync from read only once as we already store inherited security policies.
      strong_memoize_with(:sync_rules_for_project_from_read_model, project, event) do
        project.approval_policies.undeleted.pluck_primary_key.each do |security_policy_id|
          sync_project_policy(project, security_policy_id, event)
        end
      end
    end

    def use_approval_policy_rules_for_approval_rules(project)
      strong_memoize_with(:use_approval_policy_rules_for_approval_rules, project) do
        Feature.enabled?(:use_approval_policy_rules_for_approval_rules, project)
      end
    end

    def parent(event)
      parent_id = event.data[:parent_id]
      if event.data[:parent_type] == 'project'
        Project.find_by_id(parent_id)
      else
        Group.find_by_id(parent_id)
      end
    end

    def sync_project_policy(project, security_policy_id, event)
      Security::SyncProjectPolicyWorker.perform_async(
        project.id, security_policy_id, {},
        { event: { event_type: event.class.name, data: event.data } }
      )
    end
  end
end
