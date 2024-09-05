# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicyDiff
      class RuleDiff
        attr_reader :id, :from, :to

        def initialize(id:, from:, to:)
          @id = id
          @from = from
          @to = to
        end
      end
    end
  end
end
