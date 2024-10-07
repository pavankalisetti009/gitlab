# frozen_string_literal: true

module Security
  class SecurityPoliciesFinder
    def initialize(actor, policy_configurations)
      @actor = actor
      @policy_configurations = policy_configurations
    end

    def execute
      fetch_security_policies
    end

    private

    attr_reader :actor, :policy_configurations

    def fetch_security_policies
      policy_configurations.select { |config| authorized_to_read_policy_configuration?(config) }
        .each_with_object({ scan_execution_policies: [], scan_result_policies: [],
pipeline_execution_policies: [] }) do |config, policies|
        srp_policies, sep_policies, pep_policies = merge_project_relationship(config)

        policies[:scan_result_policies] += srp_policies
        policies[:scan_execution_policies] += sep_policies
        policies[:pipeline_execution_policies] += pep_policies

        policies
      end
    end

    def authorized_to_read_policy_configuration?(config)
      Ability.allowed?(actor, :read_security_orchestration_policies, config.source)
    end

    def merge_project_relationship(config)
      policy_config = {
        config: config,
        project: config.project,
        namespace: config.namespace,
        inherited: false
      }

      srp = config.scan_result_policies.map { |policy| policy.merge(policy_config) }
      sep = config.scan_execution_policy.map { |policy| policy.merge(policy_config) }
      pep = config.pipeline_execution_policy.map { |policy| policy.merge(policy_config) }

      [srp, sep, pep]
    end
  end
end
