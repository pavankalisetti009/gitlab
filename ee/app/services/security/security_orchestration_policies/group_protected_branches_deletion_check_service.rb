# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class GroupProtectedBranchesDeletionCheckService < BaseGroupService
      def execute
        all_configurations = group.all_security_orchestration_policy_configurations
        preload_security_policy_management_projects!(all_configurations)

        all_configurations.any? do |config|
          applicable_active_policies(config).any? { |policy| applies?(policy) }
        end
      end

      private

      def applicable_active_policies(config)
        config
          .active_scan_result_policies
          .reject do |policy|
          warn_mode_feature_enabled?(config) && policy[:enforcement_type] == ::Security::Policy::ENFORCEMENT_TYPE_WARN
        end
      end

      def applies?(policy)
        approval_settings = policy[:approval_settings] || (return false)

        return true if blocks_all_branch_modification?(approval_settings)

        case setting = approval_settings[:block_group_branch_modification]
        when true, false then setting
        when Hash then exceptions_permit_group?(setting)
        else false
        end
      end

      def blocks_all_branch_modification?(settings)
        # If `block_group_branch_modification` is absent and `block_branch_modification: true`,
        # we implicitly default to `block_group_branch_modification: true`
        settings[:block_branch_modification] && !settings.key?(:block_group_branch_modification)
      end

      def exceptions_permit_group?(setting)
        return false unless setting[:enabled]
        return true if setting[:exceptions].blank?

        setting[:exceptions].all? { |exception| exception[:id] != group.id }
      end

      def warn_mode_feature_enabled?(config)
        strong_memoize_with(:warn_mode_feature_enabled, config) do
          Feature.enabled?(:security_policy_approval_warn_mode, config.security_policy_management_project)
        end
      end

      # TODO: Remove with `security_policy_approval_warn_mode` feature flag
      def preload_security_policy_management_projects!(configurations)
        # rubocop:disable CodeReuse/ActiveRecord -- false positive, `configurations` is an Array
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- upper limit is 21 (maximum hierarchy depth of 20)
        project_ids = configurations.pluck(:security_policy_management_project_id)
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit
        # rubocop:enable CodeReuse/ActiveRecord
        projects_by_id = Project.id_in(project_ids).index_by(&:id)

        configurations.each do |config|
          config
            .association(:security_policy_management_project)
            .target = projects_by_id[config.security_policy_management_project_id]
        end
      end
    end
  end
end
