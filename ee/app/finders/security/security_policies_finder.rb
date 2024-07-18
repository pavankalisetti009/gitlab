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
        .each_with_object({ scan_execution_policies: [], scan_result_policies: [] }) do |config, policies|
          scan_result_policies, scan_execution_policies = merge_project_relationship(config)

          policies[:scan_result_policies] += scan_result_policies
          policies[:scan_execution_policies] += scan_execution_policies

          policies
        end
    end

    def authorized_to_read_policy_configuration?(config)
      Ability.allowed?(actor, :read_security_orchestration_policies, config.source)
    end

    def merge_project_relationship(config)
      srp = config.scan_result_policies.map do |policy|
        policy.merge(
          config: config,
          project: config.project,
          namespace: config.namespace,
          inherited: false
        )
      end

      sep = config.scan_execution_policy.map do |policy|
        policy.merge(
          config: config,
          project: config.project,
          namespace: config.namespace,
          inherited: false
        )
      end

      [srp, sep]
    end
  end
end
