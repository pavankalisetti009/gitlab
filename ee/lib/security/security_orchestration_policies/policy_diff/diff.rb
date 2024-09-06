# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicyDiff
      class Diff
        attr_reader :diff, :rules_diff

        def initialize
          @diff = {}
          @rules_diff = Security::SecurityOrchestrationPolicies::PolicyDiff::RulesDiff.new
        end

        def add_policy_field(field, from, to)
          diff[field] = Security::SecurityOrchestrationPolicies::PolicyDiff::FieldDiff.new(from: from, to: to)
        end

        delegate :add_created_rules, :add_updated_rule, :add_deleted_rule, to: :rules_diff
      end
    end
  end
end
