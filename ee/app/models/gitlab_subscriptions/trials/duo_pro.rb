# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      def self.show_duo_pro_discover?(namespace, user)
        return false unless namespace.present?
        return false unless user.present?

        ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          user.can?(:admin_namespace, namespace) &&
          GitlabSubscriptions::Trials::DuoProStatus.new(
            add_on_purchase: add_on_purchase_for_namespace(namespace.root_ancestor)
          ).show?
      end

      def self.add_on_purchase_for_namespace(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_pro, trial: true, only_active: false)
          .execute
          .first
      end
    end
  end
end
