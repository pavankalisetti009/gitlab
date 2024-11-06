# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    def self.single_eligible_namespace?(eligible_namespaces)
      return false unless eligible_namespaces.any? # executes query and now relation is loaded

      eligible_namespaces.count == 1
    end

    def self.namespace_eligible?(namespace)
      namespace_plan_eligible?(namespace) && namespace_add_on_eligible?(namespace)
    end

    def self.namespace_plan_eligible?(namespace)
      namespace.actual_plan_name.in?(::Plan::PLANS_ELIGIBLE_FOR_TRIAL)
    end

    def self.namespace_add_on_eligible?(namespace)
      Namespaces::TrialEligibleFinder.new(namespace: namespace).execute.any?
    end
  end
end
