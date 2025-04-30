# frozen_string_literal: true

module Gitlab
  module Authz
    module Ldap
      module Sync
        class AdminRole < ::Gitlab::Auth::Ldap::Sync::Base
          class << self
            def execute_all_providers
              ::Gitlab::Auth::Ldap::Config.providers.each do |provider|
                new(provider).execute
              end
            end
          end

          attr_reader :provider, :proxy

          def initialize(provider)
            @provider = provider

            adapter = Gitlab::Auth::Ldap::Adapter.new(provider)
            @proxy = EE::Gitlab::Auth::Ldap::Sync::Proxy.new(provider, adapter)
          end

          def execute
            return unless sync_enabled?

            ldap_admin_role_links.each do |link|
              ldap_users = get_member_dns(link)

              gitlab_users_by_dn = resolve_users_from_normalized_dn(for_normalized_dns: ldap_users)
              users_for_assigning_admin_roles = gitlab_users_by_dn.reject do |_k, v|
                existing_users_with_admin_roles.include?(v.id)
              end

              update_existing_admin_roles(link.member_role_id, gitlab_users_by_dn.values.map(&:id))
              assign_new_admin_roles(users_for_assigning_admin_roles, link.member_role_id)
            end

            true
          end

          private

          def sync_enabled?
            return false unless ::Feature.enabled?(:custom_admin_roles, :instance)

            true
          end

          def ldap_admin_role_links
            ::Authz::LdapAdminRoleLink.with_provider(provider)
          end

          def update_existing_admin_roles(admin_role_id, gitlab_user_ids)
            logger.debug "Updating existing admin roles for member_role_id: #{admin_role_id}"

            multiple_ldap_providers = ::Gitlab::Auth::Ldap::Config.providers.count > 1

            ldap_identity_by_user_id = resolve_ldap_identities_by_ids(for_user_ids: existing_users_with_admin_roles)

            existing_user_member_roles.each do |user_member_role|
              user = user_member_role.user
              identity = ldap_identity_by_user_id[user.id]

              next if multiple_ldap_providers && user.ldap_identity.id != identity&.id

              user_id = user.id
              # If user is still in LDAP, keep the role (already synced)
              # If not, remove the role
              if gitlab_user_ids.include?(user_id)
                # update user's role only when the actual member_role_id differs from LDAP
                if user_member_role.member_role_id != admin_role_id
                  update_user_member_role(user_member_role, admin_role_id)
                end
              else
                # User is no longer in LDAP, remove the role
                user_member_role.destroy
                logger.info("Successfully removed admin role for user ID: #{user_id}")
              end
            end
          end

          def existing_user_member_roles
            @existing_user_member_roles ||= ::Users::UserMemberRole.ldap_synced
          end

          def existing_users_with_admin_roles
            existing_user_member_roles.map(&:user_id)
          end

          def assign_new_admin_roles(users, admin_role_id)
            logger.debug "Adding new admin roles for member_role_id: #{admin_role_id}"

            # After update_existing_admin_roles, gitlab_users should only contain users that need new roles
            users.each_value do |user|
              next if user.admin? # rubocop: disable Cop/UserAdmin -- Direct admin check is needed for LDAP sync

              admin_role_user = ::Users::UserMemberRole.new(user: user, member_role_id: admin_role_id, ldap: true)

              if admin_role_user.save
                logger.info("Successfully created admin role for user ID: #{user.id}")
              else
                errors = admin_role_user.errors.full_messages.join(', ')
                logger.error("Failed to save admin role for user ID: #{user.id}. Errors: #{errors}")
              end
            end
          end

          def update_user_member_role(user_member_role, member_role_id)
            user_member_role.member_role_id = member_role_id

            if user_member_role.save
              logger.info(
                "Successfully updated admin role for user ID: #{user_member_role.user_id}
                to member_role_id: #{member_role_id}"
              )
            else
              errors = user_member_role.errors.full_messages.join(', ')
              logger.error("Failed to update admin role for user ID: #{user_member_role.user_id}. Errors: #{errors}")
            end
          end
        end
      end
    end
  end
end
