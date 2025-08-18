# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillUserGroupMemberRoles
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_user_group_member_roles
          feature_category :permissions
          scope_to ->(relation) do
            relation.where.not(member_role_id: nil).where(source_type: 'Namespace', state: 0)
          end
        end

        class UserGroupMemberRole < ::ApplicationRecord
          self.table_name = 'user_group_member_roles'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            members_with_member_role = sub_batch.map do |member|
              {
                user_id: member.user_id,
                group_id: member.source_id,
                member_role_id: member.member_role_id,
                shared_with_group_id: nil
              }
            end

            UserGroupMemberRole.upsert_all(
              members_with_member_role,
              returning: false,
              unique_by: %i[user_id group_id]
            )
          end
        end
      end
    end
  end
end
