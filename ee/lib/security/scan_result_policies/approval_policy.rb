# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class ApprovalPolicy < Security::BaseSecurityPolicy
      def enforcement_type
        Security::ScanResultPolicies::EnforcementType.new(policy_content[:enforcement_type])
      end

      def fallback_behavior
        Security::ScanResultPolicies::FallbackBehavior.new(policy_content[:fallback_behavior] || {})
      end

      def policy_tuning
        Security::ScanResultPolicies::PolicyTuning.new(policy_content[:policy_tuning] || {})
      end

      def bypass_settings
        Security::ScanResultPolicies::BypassSettings.new(policy_content[:bypass_settings] || {})
      end

      def actions
        Security::ScanResultPolicies::Actions.new(policy_content[:actions] || [])
      end

      def approval_settings
        Security::ScanResultPolicies::ApprovalSettings.new(policy_content[:approval_settings] || {})
      end

      def rules
        Security::ScanResultPolicies::Rules
          .new(policy_record.rules.map(&:typed_content).map(&:deep_symbolize_keys) || [])
      end

      private

      def policy_content
        policy_record.policy_content
      end
    end
  end
end
