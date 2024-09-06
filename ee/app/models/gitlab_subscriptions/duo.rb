# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    def self.any_add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(namespace, add_on: :duo, only_active: false).execute.first
    end

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo, only_active: false).execute.none?
    end
  end
end
