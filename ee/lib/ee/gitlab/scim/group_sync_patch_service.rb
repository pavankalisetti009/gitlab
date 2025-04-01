# frozen_string_literal: true

module EE
  module Gitlab
    module Scim
      # rubocop:disable Gitlab/EeOnlyClass -- All existing instance SCIM code
      # currently lives under ee/ and making it compliant requires a larger
      # refactor to be addressed by https://gitlab.com/gitlab-org/gitlab/-/issues/520129.
      class GroupSyncPatchService
        attr_reader :group_links, :operations

        def initialize(group_links:, operations:)
          @group_links = group_links
          @operations = operations
        end

        def execute
          operations.each do |operation|
            process_operation(operation)
          end

          ServiceResponse.success
        end

        private

        def process_operation(operation)
          case operation[:path].to_s.downcase
          when 'externalid'
            # NO-OP
            #
            # For now we just accept the externalId update but don't store it.
            # In some IdPs (e.g. Microsoft Entra), this is part of the group
            # sync provisioning cycle.
          when 'members'
            process_members(operation[:value])
          end
        end

        def process_members(members)
          return unless members.is_a?(Array)

          members.each do |member|
            member_id = member[:value]
            next unless member_id

            user = find_user_identity(member_id)&.user
            next unless user

            add_user_to_groups(user)
          end
        end

        def add_user_to_groups(user)
          group_links.each do |saml_group_link|
            next unless saml_group_link.group

            unless saml_group_link.group.users.include?(user)
              saml_group_link.group.add_member(user, saml_group_link.access_level)
            end
          end
        end

        def find_user_identity(extern_uid)
          ScimIdentity.for_instance.with_extern_uid(extern_uid).first
        end
      end
      # rubocop:enable Gitlab/EeOnlyClass
    end
  end
end
