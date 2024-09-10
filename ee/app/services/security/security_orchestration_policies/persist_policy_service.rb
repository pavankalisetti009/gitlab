# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PersistPolicyService
      include BaseServiceUtility
      include Gitlab::Loggable
      include Gitlab::Utils::StrongMemoize

      def initialize(policy_configuration:, policies:, policy_type:)
        @policy_configuration = policy_configuration
        @policies = policies
        @policy_type = case policy_type
                       when :approval_policy, :scan_result_policy then :approval_policy
                       when :scan_execution_policy then :scan_execution_policy
                       when :pipeline_execution_policy then :pipeline_execution_policy
                       else raise ArgumentError, "unrecognized policy_type"
                       end
      end

      def execute
        Gitlab::AppJsonLogger.debug(
          build_structured_payload(
            security_orchestration_policy_configuration_id: policy_configuration.id,
            policies: policies
          )
        )

        new_policies, deleted_policies, policies_changes, rearranged_policies = categorize_policies

        ApplicationRecord.transaction do
          mark_policies_for_deletion(deleted_policies)
          update_rearranged_policies(rearranged_policies)
          create_policies(new_policies)
          update_policies(policies_changes)
        end

        success
      rescue StandardError => e
        error(e.message)
      end

      private

      attr_reader :policy_configuration, :policies, :policy_type

      delegate :security_policies, to: :policy_configuration

      def db_policies
        policy_configuration.security_policies.undeleted.merge(relation_scope)
      end
      strong_memoize_attr :db_policies

      def categorize_policies
        db_policies_with_checksums = db_policies.index_by(&:checksum)
        db_policies_with_names = db_policies.index_by(&:name)

        deleted_policies = db_policies_with_checksums.values
        new_policies = []
        policies_changes = []
        rearranged_policies = []

        policies.each_with_index do |policy_hash, index|
          checksum = Security::Policy.checksum(policy_hash)
          db_policy = db_policies_with_checksums[checksum] || db_policies_with_names[policy_hash[:name]]

          next new_policies << [policy_hash, index] unless db_policy

          deleted_policies.delete(db_policy)

          if db_policy.checksum != checksum
            policies_changes << Security::SecurityOrchestrationPolicies::PolicyComparer.new(
              db_policy: db_policy, yaml_policy: policy_hash, policy_index: index
            )
          end

          rearranged_policies << [db_policy, index] if db_policy.policy_index != index
        end

        [new_policies, deleted_policies, policies_changes, rearranged_policies]
      end

      def create_policies(new_policies)
        new_policies.map do |policy_hash, index|
          Security::Policy.upsert_policy(policy_type, security_policies, policy_hash, index, policy_configuration)
        end
      end

      def update_policies(policies_changes)
        return if policies_changes.empty?

        Security::SecurityOrchestrationPolicies::UpdateSecurityPoliciesService.new(
          policies_changes: policies_changes
        ).execute
      end

      def mark_policies_for_deletion(deleted_policies)
        return if deleted_policies.empty?

        max_index = (db_policies.maximum(:policy_index) + 1) || 0
        deleted_policies.each_with_index do |policy, index|
          new_index = max_index + index
          policy.update!(policy_index: -new_index, enabled: false)
        end
      end

      # Updates in two steps to avoid unique constraint violations
      def update_rearranged_policies(rearranged_policies)
        rearranged_policies.each_with_index do |(policy, _), temp_index|
          policy.update!(policy_index: -1 - temp_index) # assign a negative temporary index
        end

        rearranged_policies.each do |policy, new_index|
          policy.update!(policy_index: new_index)
        end
      end

      def relation_scope
        case policy_type
        when :approval_policy then Security::Policy.type_approval_policy
        when :scan_execution_policy then Security::Policy.type_scan_execution_policy
        when :pipeline_execution_policy then Security::Policy.type_pipeline_execution_policy
        end
      end
    end
  end
end
