# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module MigrateAiCodeSuggestionEvents
        extend ::Gitlab::Utils::Override

        COPY_QUERY = <<~SQL
          INSERT INTO ai_usage_events
          (
            timestamp,
            user_id,
            organization_id,
            created_at,
            event,
            extras,
            namespace_id
          )
          SELECT
            timestamp,
            user_id,
            organization_id,
            created_at,
            event,
            payload AS extras,
            CASE
              WHEN namespace_path IS NULL THEN NULL
              ELSE (
                SELECT id FROM namespaces
                WHERE id = regexp_replace(namespace_path, '(?:.*/)?([0-9]+)/$', '\\1')::bigint
                LIMIT 1
              )
            END AS namespace_id
          FROM (%{sub_batch_query}) AS rows
          ON CONFLICT (namespace_id, user_id, event, timestamp) DO NOTHING
        SQL

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            connection.execute(format(COPY_QUERY, sub_batch_query: sub_batch.limit(sub_batch_size).to_sql))
          end
        end
      end
    end
  end
end
