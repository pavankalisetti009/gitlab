# frozen_string_literal: true

module Namespaces
  module ServiceAccounts
    class CreateService < ::Users::ServiceAccounts::CreateService
      extend ::Gitlab::Utils::Override

      attr_accessor :uniquify_provided_username

      def initialize(current_user, params = {}, uniquify_provided_username: false)
        super(current_user, params)

        @uniquify_provided_username = uniquify_provided_username
      end

      private

      override :create_user
      def create_user
        ::Users::AuthorizedCreateService.new(current_user, default_user_params).execute
      end

      def resource
        return Project.find_by_id(params[:project_id]) if params[:project_id].present?

        Namespace.id_in(params[:namespace_id]).first if params[:namespace_id].present?
      end
      strong_memoize_attr :resource

      def project_level?
        resource.is_a?(::Project)
      end

      def resource_type
        params[:project_id].present? ? 'project' : 'group'
      end

      def root_namespace
        resource&.root_ancestor
      end
      strong_memoize_attr :root_namespace

      def username_prefix
        "#{User::SERVICE_ACCOUNT_PREFIX}_#{resource_type}_#{resource.id}"
      end

      override :username
      def username
        if uniquify_provided_username && username_unavailable?(params[:username])
          return uniquify_username(params[:username] || username_prefix)
        end

        super
      end

      def uniquify_username(prefix)
        Gitlab::Utils::UsernameAndEmailGenerator.new(
          username_prefix: prefix,
          random_segment: SecureRandom.hex(3)
        ).username
      end

      override :default_user_params
      def default_user_params
        super.merge(provisioning_params)
      end

      def provisioning_params
        return { provisioned_by_project_id: resource.id } if project_level?

        {
          group_id: resource.id,
          provisioned_by_group_id: resource.id
        }
      end

      override :error_messages
      def error_messages
        super.merge(
          no_permission:
            format(
              s_('ServiceAccount|User does not have permission to create a service account in this %{resource_type}.'),
              resource_type: resource_type)
        )
      end

      override :can_create_service_account?
      def can_create_service_account?
        return false unless resource
        return true if skip_owner_check?

        can?(current_user, :create_service_account, resource)
      end

      def skip_owner_check?
        # Allow service account creation for AI catalog items when the user has
        # :admin_ai_catalog_item_consumer permission. This enables maintainers/developers
        # to enable foundational flows without requiring group owner privileges.
        # Only applicable to group-level service accounts
        return false if project_level?

        params[:skip_owner_check] == true && params[:composite_identity_enforced] == true
      end

      override :active_subscription?
      def active_subscription?
        return super unless saas?

        group_subscription = root_namespace.gitlab_subscription
        return false unless group_subscription
        return false if group_subscription.expired?
        return false unless group_subscription.plan_name

        return true if paid_non_trial_subscription?(group_subscription)
        return true if trial_with_unlimited_service_accounts?

        GitlabSubscription::SERVICE_ACCOUNT_LIMIT_FOR_TRIAL > service_accounts_provisioned_count
      end

      def paid_non_trial_subscription?(subscription)
        !root_namespace.trial_active? && Plan::PAID_HOSTED_PLANS.include?(subscription.plan_name)
      end

      def trial_with_unlimited_service_accounts?
        root_namespace.trial_active? &&
          ::Feature.enabled?(:allow_unlimited_service_account_for_trials, root_namespace)
      end

      def username_unavailable?(username)
        ::Namespace.by_path(username) || ::User.username_exists?(username)
      end

      def service_accounts_provisioned_count
        return service_accounts_in_hierarchy_count if count_hierarchy_service_accounts?

        service_accounts_provisioned_by_group_count
      end

      def count_hierarchy_service_accounts?
        ::Feature.enabled?(:allow_projects_to_create_service_accounts, root_namespace)
      end

      def service_accounts_provisioned_by_group_count
        ::User
          .service_accounts_without_composite_identity
          .with_provisioning_group(root_namespace.self_and_descendants)
          .count
      end

      def service_accounts_in_hierarchy_count
        return 0 unless root_namespace

        namespace_ids = root_namespace.self_and_descendant_ids

        # rubocop: disable CodeReuse/ActiveRecord -- this is an optimized query to count service accounts across group
        # hierarchy for subcscription, its not used anywhere else.
        group_provisioned_scope = ::User
          .service_accounts_without_composite_identity
          .with_provisioning_group(namespace_ids)
          .select(:id)

        project_ids = Project.where(namespace_id: namespace_ids).select(:id)
        project_provisioned_scope = ::User
          .service_accounts_without_composite_identity
          .joins(:user_detail)
          .where(user_details: { provisioned_by_project_id: project_ids })
          .select(:id)

        ::User.from_union([group_provisioned_scope, project_provisioned_scope]).count
        # rubocop: enable CodeReuse/ActiveRecord
      end

      def saas?
        root_namespace && ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end
      strong_memoize_attr :saas?
    end
  end
end
