# frozen_string_literal: true

module Security
  class PolicyScope
    def initialize(policy_scope)
      @policy_scope = policy_scope || {}
    end

    def compliance_frameworks
      policy_scope[:compliance_frameworks] || []
    end

    def projects
      policy_scope[:projects] || {}
    end

    def groups
      policy_scope[:groups] || {}
    end

    private

    attr_reader :policy_scope
  end
end
