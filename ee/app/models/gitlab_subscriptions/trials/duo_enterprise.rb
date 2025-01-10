# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      extend ::GitlabSubscriptions::SubscriptionHelper

      def self.any_add_on_purchase_for_namespace(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_enterprise, trial: true, only_active: false)
          .execute
          .first
      end

      def self.any_add_on_purchased_or_trial?(namespace)
        add_on_purchase = if gitlab_com_subscription?
                            GitlabSubscriptions::DuoEnterprise
                              .any_pro_enterprise_add_on_purchase_for_namespace(namespace)
                          else
                            # for non SaaS environments we need to look for add-on purchase related to
                            # self managed instance
                            GitlabSubscriptions::DuoEnterprise.any_pro_enterprise_add_on_purchase_for_namespace(nil)
                          end

        return false unless add_on_purchase.present?

        if add_on_purchase.trial?
          GitlabSubscriptions::Trials::AddOnStatus.new(add_on_purchase: add_on_purchase).show?
        else
          add_on_purchase.active?
        end
      end

      def self.active_add_on_purchase_for_namespace?(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_enterprise, trial: true, only_active: true).execute.any?
      end

      def self.show_duo_enterprise_discover?(namespace, user)
        return false unless namespace.present?
        return false unless user.present?

        ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          user.can?(:admin_namespace, namespace) &&
          GitlabSubscriptions::Trials::AddOnStatus.new(
            add_on_purchase: any_add_on_purchase_for_namespace(namespace.root_ancestor)
          ).show?
      end
    end
  end
end
