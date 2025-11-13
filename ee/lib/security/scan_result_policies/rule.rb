# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class Rule
      def initialize(rule)
        @rule = rule || {}
      end

      def type
        rule[:type]
      end

      def branches
        rule[:branches]
      end

      def branch_type
        rule[:branch_type]
      end

      def scanners
        rule[:scanners]
      end

      def vulnerabilities_allowed
        rule[:vulnerabilities_allowed]
      end

      def severity_levels
        rule[:severity_levels]
      end

      def vulnerability_states
        rule[:vulnerability_states]
      end

      def commits
        rule[:commits]
      end

      def branch_exceptions
        rule[:branch_exceptions] || []
      end

      def vulnerability_attributes
        rule[:vulnerability_attributes] || {}
      end

      def vulnerability_age
        rule[:vulnerability_age] || {}
      end

      def match_on_inclusion_license
        rule[:match_on_inclusion_license]
      end

      def license_types
        rule[:license_types] || []
      end

      def license_states
        rule[:license_states] || []
      end

      def licenses
        rule[:licenses] || {}
      end

      private

      attr_reader :rule
    end
  end
end
