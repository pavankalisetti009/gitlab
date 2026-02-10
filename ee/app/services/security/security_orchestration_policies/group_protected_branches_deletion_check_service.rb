# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class GroupProtectedBranchesDeletionCheckService < BaseGroupService
      BlockingPolicy = Data.define(:policy_configuration_id, :security_policy_name)

      def initialize(group:, params: {}, ignore_warn_mode: false)
        super(group: group)
        @params = params
        @ignore_warn_mode = ignore_warn_mode
      end

      def execute
        all_configurations = group.all_security_orchestration_policy_configurations

        all_configurations.each do |config|
          applicable_active_policies(config).each do |policy|
            next unless applies?(policy)

            return true unless collect_blocking_policies?

            blocking_policies << BlockingPolicy.new(config.id, policy[:name])
          end
        end

        blocking_policies.any?
      end

      def blocking_policies
        @blocking_policies ||= []
      end

      private

      attr_reader :ignore_warn_mode, :params

      def applicable_active_policies(config)
        policies = config.active_scan_result_policies

        if warn_mode_policies_only?
          return [] if ignore_warn_mode

          policies.select { |policy| warn_mode?(policy) }
        else
          policies.reject do |policy|
            !ignore_warn_mode && warn_mode?(policy)
          end
        end
      end

      def collect_blocking_policies?
        params[:collect_blocking_policies]
      end

      def warn_mode_policies_only?
        params[:policy_enforcement_type] == ::Security::Policy::ENFORCEMENT_TYPE_WARN
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

      def warn_mode?(policy)
        policy[:enforcement_type] == ::Security::Policy::ENFORCEMENT_TYPE_WARN
      end
    end
  end
end
