# frozen_string_literal: true

module EE
  module Gitlab
    module Scim
      # rubocop:disable Gitlab/EeOnlyClass -- All existing instance SCIM code
      # currently lives under ee/ and making it compliant requires a larger
      # refactor to be addressed by https://gitlab.com/gitlab-org/gitlab/-/issues/520129.
      class GroupSyncPutService
        attr_reader :scim_group_uid, :members, :display_name

        def initialize(scim_group_uid:, members:, display_name:)
          @scim_group_uid = scim_group_uid
          @members = members
          @display_name = display_name
        end

        def execute
          sync_group_membership

          ServiceResponse.success
        end

        private

        def sync_group_membership
          return unless members.is_a?(Array)

          normalized_members = members.reject(&:blank?)
          target_user_ids = fetch_target_user_ids(normalized_members)

          group_links = SamlGroupLink.by_scim_group_uid(scim_group_uid)
          users_to_remove = group_links.flat_map do |saml_group_link|
            find_users_to_remove(saml_group_link, target_user_ids)
          end.uniq

          if users_to_remove.any?
            ::Authn::SyncScimGroupMembersWorker.perform_async(
              scim_group_uid,
              users_to_remove,
              'remove'
            )
          end

          return unless target_user_ids.any?

          ::Authn::SyncScimGroupMembersWorker.perform_async(
            scim_group_uid,
            target_user_ids,
            'add'
          )
        end

        def fetch_target_user_ids(normalized_members)
          extern_uids = normalized_members.filter_map { |member| member[:value] }
          return [] if extern_uids.empty?

          scim_identities = ScimIdentity.for_instance.with_extern_uid(extern_uids)
          scim_identities.map(&:user_id)
        end

        def find_users_to_remove(saml_group_link, target_user_ids)
          current_scim_user_ids = find_current_scim_user_ids(saml_group_link.group)

          # Calculate the difference between current SCIM users in this group and the target users
          # from the SCIM request. This identifies users who were previously provisioned via SCIM
          # but are no longer included in the PUT request's member list. These users need to be
          # removed from the group as part of the synchronization process.
          current_scim_user_ids - target_user_ids
        end

        def find_current_scim_user_ids(group)
          group_user_ids = group.user_ids

          ScimIdentity.for_instance.with_user_ids(group_user_ids).map(&:user_id)
        end
      end
      # rubocop:enable Gitlab/EeOnlyClass
    end
  end
end
