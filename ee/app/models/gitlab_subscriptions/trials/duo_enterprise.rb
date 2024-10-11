# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      def self.add_on_purchase_for_namespace(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_enterprise, trial: true, only_active: false)
          .execute
          .first
      end
    end
  end
end
