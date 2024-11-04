# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    def self.single_eligible_namespace?(eligible_namespaces)
      return false unless eligible_namespaces.any? # executes query and now relation is loaded

      eligible_namespaces.count == 1
    end

    def self.namespace_eligible?(namespace)
      namespace.actual_plan_name.in?(::Plan::PLANS_ELIGIBLE_FOR_TRIAL)
    end
  end
end
