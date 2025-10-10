# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class ApprovalSettingsOverrides
      include Gitlab::Utils::StrongMemoize

      Override = Data.define(:attribute, :security_policies)

      def initialize(project:, security_policies:)
        @project = project
        @security_policies = security_policies
        @policy_settings_index = {}
      end

      def all
        project_settings.filter_map do |attr, val|
          # If the project setting is restrictive, it can't be overridden.
          next if val

          # Does a policy override the attribute?
          next unless policies_approval_settings[attr]

          Override.new(attr, policy_settings_index.fetch(attr))
        end
      end

      private

      attr_reader :project,
        :security_policies,
        :policy_settings_index

      def project_settings
        {
          prevent_approval_by_author: !project.merge_requests_author_approval?,
          prevent_approval_by_commit_author: project.merge_requests_disable_committers_approval?,
          remove_approvals_with_new_commit: project.reset_approvals_on_push?,
          require_password_to_approve: project.require_password_to_approve?
        }
      end

      def policies_approval_settings
        security_policies.reduce({}) do |acc, policy|
          settings = policy
                       .content
                       .fetch("approval_settings", {})
                       .symbolize_keys

          next acc unless settings.present?

          index_policy(policy, settings)

          # If there are multiple policies with a conflicting property,
          # eg. {true, false}, then the aggregate property is determined by
          # logical OR, so that more restrictive policies take precedence.
          acc.merge(settings) { |_key, old_val, new_val| old_val || new_val }
        end
      end
      strong_memoize_attr :policies_approval_settings

      def index_policy(policy, settings)
        settings.each do |attr, val|
          next unless val # permissive?

          (policy_settings_index[attr] ||= Set.new) << policy
        end
      end
    end
  end
end
