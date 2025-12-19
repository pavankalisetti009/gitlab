# frozen_string_literal: true

# This class is the object representation of a single entry in the policy.yml
module Security
  module ScanExecutionPolicy
    class Config
      include ::Security::PolicyCiSkippable

      DEFAULT_SKIP_CI_STRATEGY = { allowed: true }.freeze

      attr_reader :actions, :configuration, :skip_ci_strategy, :name

      def initialize(policy:, configuration: nil)
        @configuration = configuration
        @skip_ci_strategy = policy[:skip_ci].presence || DEFAULT_SKIP_CI_STRATEGY
        @name = policy.fetch(:name)
        @actions = policy.fetch(:actions, []).map { |action| action.merge(metadata: action_metadata) }
      end

      def skip_ci_allowed?(user_id)
        skip_ci_allowed_for_strategy?(skip_ci_strategy, user_id)
      end

      private

      delegate :security_policy_management_project_id, :configuration_sha, to: :configuration, allow_nil: true

      def action_metadata
        # Metadata used for id_tokens. It matches the attributes in `pipeline_execution_context.job_options`.
        {
          name: name,
          project_id: security_policy_management_project_id,
          sha: configuration_sha
        }.compact
      end
    end
  end
end
