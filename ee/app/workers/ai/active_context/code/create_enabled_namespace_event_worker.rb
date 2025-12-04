# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class CreateEnabledNamespaceEventWorker
        include Gitlab::EventStore::Subscriber
        include Gitlab::Utils::StrongMemoize
        prepend ::Geo::SkipSecondary

        feature_category :global_search
        deduplicate :until_executed
        data_consistency :sticky
        urgency :low
        idempotent!
        defer_on_database_health_signal :gitlab_main,
          [:p_ai_active_context_code_enabled_namespaces, :gitlab_subscriptions],
          10.minutes

        BATCH_SIZE = 1000

        def handle_event(_)
          return false unless eligible_instance?
          return false unless ::Ai::ActiveContext::Collections::Code.indexing?

          process_in_batches!
        end

        private

        def eligible_instance?
          return true if gitlab_com

          return false unless ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
          return false unless ::License.ai_features_available?

          true
        end

        def process_in_batches!
          total_count = 0

          Namespace.group_namespaces.top_level.each_batch(of: BATCH_SIZE) do |batch|
            namespace_ids = if gitlab_com
                              filter_eligible_namespace_ids(batch).pluck_primary_key
                            else
                              batch.pluck_primary_key
                            end

            eligible_namespace_ids = namespace_ids - existing_namespace_ids(namespace_ids)

            next if eligible_namespace_ids.empty?

            records_to_insert = eligible_namespace_ids.map do |namespace_id|
              { namespace_id: namespace_id, connection_id: active_connection.id, state: 'ready' }
            end

            Ai::ActiveContext::Code::EnabledNamespace.insert_all(
              records_to_insert,
              unique_by: %w[connection_id namespace_id]
            )

            total_count += records_to_insert.size

            if total_count >= BATCH_SIZE
              reemit_event
              break
            end
          end

          log_extra_metadata_on_done(:enabled_namespaces_created, total_count)
        end

        def reemit_event
          Gitlab::EventStore.publish(CreateEnabledNamespaceEvent.new(data: {}))
        end

        def filter_eligible_namespace_ids(namespace_batch)
          Namespace
            .id_in(namespace_batch.pluck_primary_key)
            .namespace_settings_with_ai_features_enabled
            .with_ai_supported_plan
            .merge(GitlabSubscription.not_expired)
        end

        def existing_namespace_ids(namespace_ids)
          active_connection.enabled_namespaces.namespace_id_in(namespace_ids).map(&:namespace_id)
        end

        def active_connection
          Ai::ActiveContext::Connection.active
        end
        strong_memoize_attr :active_connection

        def gitlab_com
          ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
        end
        strong_memoize_attr :gitlab_com
      end
    end
  end
end
