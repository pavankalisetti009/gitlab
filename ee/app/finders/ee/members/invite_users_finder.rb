# frozen_string_literal: true

module EE
  module Members
    module InviteUsersFinder
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      private

      def root_group
        root_ancestor = resource.root_ancestor

        root_ancestor if root_ancestor.group_namespace?
      end
      strong_memoize_attr :root_group

      def target_group
        case resource
        when Project
          resource.group
        when Group
          resource
        end
      end
      strong_memoize_attr :target_group

      override :scope_for_resource
      def scope_for_resource(users)
        if root_group && root_group.enforced_sso?
          ::User.from_union(
            users.with_saml_provider(root_group.saml_provider),
            users.service_account.with_provisioning_group(root_group)
          )
        else
          scoped_users = super
          ::Namespaces::ServiceAccounts::MembershipEligibilityChecker.new(target_group).filter_users(scoped_users)
        end
      end
    end
  end
end
