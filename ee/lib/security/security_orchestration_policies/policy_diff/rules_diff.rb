# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicyDiff
      class RulesDiff
        attr_accessor :created, :updated, :deleted

        def initialize
          @created = []
          @updated = []
          @deleted = []
        end

        def add_created_rules(new_rules)
          created.concat(new_rules)
        end

        def add_deleted_rule(deleted_rule)
          deleted << RuleDiff.new(id: deleted_rule.id, from: deleted_rule, to: nil)
        end

        def add_updated_rule(updated_rule, from, to)
          updated << RuleDiff.new(id: updated_rule.id, from: from, to: to)
        end
      end
    end
  end
end
