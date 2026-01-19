# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    class CleanupSecurityPolicyBotUsers < BatchedMigrationJob
      operation_name :cleanup_security_policy_bot_users
      feature_category :security_policy_management

      SECURITY_POLICY_BOT_TYPE = 10

      # rubocop:disable Database/AvoidScopeTo -- supporting index: index_users_on_user_type_and_id
      scope_to ->(relation) { relation.where(user_type: SECURITY_POLICY_BOT_TYPE) }
      # rubocop:enable Database/AvoidScopeTo

      def perform
        each_sub_batch do |sub_batch|
          deleted_ids = connection.select_values(<<~SQL)
            DELETE FROM users
            WHERE id IN (#{sub_batch.select(:id).to_sql})
              AND NOT EXISTS (
                SELECT 1
                FROM members
                INNER JOIN projects ON projects.id = members.source_id
                INNER JOIN namespaces ON namespaces.id = projects.namespace_id
                INNER JOIN gitlab_subscriptions ON gitlab_subscriptions.namespace_id = namespaces.traversal_ids[1]
                INNER JOIN plans ON plans.id = gitlab_subscriptions.hosted_plan_id
                WHERE members.user_id = users.id
                  AND members.source_type = 'Project'
                  AND members.type = 'ProjectMember'
                  AND plans.name = 'ultimate'
              )
            RETURNING id
          SQL

          next unless deleted_ids.any?

          Gitlab::BackgroundMigration::Logger.info(
            migrator: self.class.name,
            message: 'Deleted security policy bot users',
            count: deleted_ids.size,
            user_ids: deleted_ids
          )
        end
      end
    end
  end
end
