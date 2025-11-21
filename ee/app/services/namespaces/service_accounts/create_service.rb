# frozen_string_literal: true

module Namespaces
  module ServiceAccounts
    class CreateService < ::Users::ServiceAccounts::CreateService
      extend ::Gitlab::Utils::Override

      private

      override :create_user
      def create_user
        ::Users::AuthorizedCreateService.new(current_user, default_user_params).execute
      end

      def namespace
        namespace_id = params[:namespace_id]
        return unless namespace_id

        Namespace.id_in(namespace_id).first
      end
      strong_memoize_attr :namespace

      override :username_prefix
      def username_prefix
        "#{User::SERVICE_ACCOUNT_PREFIX}_#{namespace.type.downcase}_#{namespace.id}"
      end

      override :default_user_params
      def default_user_params
        super.merge(
          group_id: params[:namespace_id],
          provisioned_by_group_id: params[:namespace_id]
        )
      end

      override :error_messages
      def error_messages
        super.merge(
          no_permission:
            s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
        )
      end

      override :can_create_service_account
      def can_create_service_account?
        return false unless namespace

        can?(current_user, :create_service_account, namespace)
      end

      override :ultimate?
      def ultimate?
        return super unless saas?
        return false if namespace.trial? # hosted plan can be ultimate even if a group is on trial

        plan_name = namespace.actual_plan_name
        [::Plan::GOLD, ::Plan::ULTIMATE].include?(plan_name)
      end

      override :seats_available?
      def seats_available?
        return super unless saas?
        return true if ultimate?

        limit = if namespace.trial_active?
                  GitlabSubscription::SERVICE_ACCOUNT_LIMIT_FOR_TRIAL
                else
                  namespace.gitlab_subscription.seats
                end

        limit > namespace.provisioned_users.service_account.count
      end

      def saas?
        namespace && ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end
      strong_memoize_attr :saas?
    end
  end
end
