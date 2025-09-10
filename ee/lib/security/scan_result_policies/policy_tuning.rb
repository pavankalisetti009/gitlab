# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class PolicyTuning
      def initialize(policy_tuning)
        @policy_tuning = policy_tuning || {}
      end

      def security_report_time_window
        policy_tuning[:security_report_time_window]
      end

      private

      attr_reader :policy_tuning
    end
  end
end
