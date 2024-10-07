# frozen_string_literal: true

module Gitlab
  module Graphql
    module Aggregations
      module SecurityOrchestrationPolicies
        class LazyComplianceFrameworkAggregate
          include ::Gitlab::Graphql::Deferred
          include ConstructSecurityPolicies

          attr_reader :object, :policy_type, :lazy_state, :current_user

          def initialize(query_ctx, object, policy_type)
            @current_user = query_ctx[:current_user]
            @object = Gitlab::Graphql::Lazy.force(object)
            @policy_type = policy_type

            @lazy_state = query_ctx[:lazy_compliance_framework_in_policies_aggregate] ||= {
              pending_frameworks: [],
              loaded_objects: Hash.new { |h, k| h[k] = {} }
            }
            @lazy_state[:pending_frameworks] << object
          end

          def execute
            load_records_into_loaded_objects if @lazy_state[:pending_frameworks].present?

            @lazy_state[:loaded_objects][@object.id][policy_type]
          end

          private

          def load_records_into_loaded_objects
            policy_configurations_by_frameworks = @lazy_state[:pending_frameworks]
              .index_with(&:security_orchestration_policy_configurations)

            policy_configurations_by_frameworks.each do |framework, configurations|
              policies = security_policies(configurations)
              scan_result_policies = construct_scan_result_policies(
                filter_policies_by_scope(policies[:scan_result_policies], framework.id)
              )
              scan_execution_policies = construct_scan_execution_policies(
                filter_policies_by_scope(policies[:scan_execution_policies], framework.id)
              )
              pipeline_execution_policies = construct_pipeline_execution_policies(
                filter_policies_by_scope(policies[:pipeline_execution_policies], framework.id)
              )

              @lazy_state[:loaded_objects][framework.id] ||= {}
              @lazy_state[:loaded_objects][framework.id][:scan_result_policies] = Array.wrap(
                @lazy_state.dig(:loaded_objects, framework.id, :scan_result_policies)) + scan_result_policies

              @lazy_state[:loaded_objects][framework.id][:scan_execution_policies] = Array.wrap(
                @lazy_state.dig(:loaded_objects, framework.id, :scan_execution_policies)) + scan_execution_policies

              @lazy_state[:loaded_objects][framework.id][:pipeline_execution_policies] = Array.wrap(
                @lazy_state.dig(:loaded_objects, framework.id, :pipeline_execution_policies)) +
                pipeline_execution_policies
            end

            @lazy_state[:pending_frameworks].clear
          end

          def filter_policies_by_scope(policies, framework_id)
            policies.select do |policy|
              policy.dig(:policy_scope, :compliance_frameworks)&.any? do |compliance_framework|
                compliance_framework[:id] == framework_id
              end
            end
          end

          def security_policies(configurations)
            ::Security::SecurityPoliciesFinder.new(@current_user, configurations).execute
          end
        end
      end
    end
  end
end
