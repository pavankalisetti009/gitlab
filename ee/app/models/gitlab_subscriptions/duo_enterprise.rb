# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterprise
    ELIGIBLE_PLANS = [::Plan::ULTIMATE, ::Plan::ULTIMATE_TRIAL].freeze

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, only_active: false, add_on: :duo_enterprise).execute.none?
    end

    def self.namespace_eligible?(namespace)
      namespace.actual_plan_name.in?(ELIGIBLE_PLANS) && no_add_on_purchase_for_namespace?(namespace)
    end
  end
end
