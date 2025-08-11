# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PushBypassChecker
      include Gitlab::Utils::StrongMemoize

      def initialize(project:, user_access:, branch_name:, push_options:)
        @project = project
        @user_access = user_access
        @branch_name = branch_name
        @push_options = push_options
      end

      def check_bypass!
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        policies = project.security_policies.with_bypass_settings
        return if policies.empty?

        policies.any? { |policy| bypass_allowed?(policy) }
      end

      private

      attr_reader :project, :user_access, :branch_name, :push_options

      def bypass_allowed?(policy)
        Security::ScanResultPolicies::PolicyBypassChecker.new(
          security_policy: policy,
          project: project,
          user_access: user_access,
          branch_name: branch_name,
          push_options: push_options
        ).bypass_allowed?
      rescue Security::ScanResultPolicies::PolicyBypassChecker::BypassReasonRequiredError
        raise
      end
    end
  end
end
