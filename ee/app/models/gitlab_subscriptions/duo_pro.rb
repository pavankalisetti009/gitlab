# frozen_string_literal: true

module GitlabSubscriptions
  module DuoPro
    def self.add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(namespace, add_on: :duo_pro).execute.first
    end

    def self.any_add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo_pro, only_active: false).execute.first
    end

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo_pro, only_active: false).execute.none?
    end

    def self.no_active_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(namespace, add_on: :duo_pro).execute.none?
    end
  end
end
