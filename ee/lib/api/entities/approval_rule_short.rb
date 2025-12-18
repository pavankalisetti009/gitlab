# frozen_string_literal: true

module API
  module Entities
    class ApprovalRuleShort < Grape::Entity
      expose :id, documentation: { type: 'Integer', example: 1 }
      expose :name, documentation: { example: 'QA' }
      expose :rule_type, documentation: { example: 'regular' }
    end
  end
end
