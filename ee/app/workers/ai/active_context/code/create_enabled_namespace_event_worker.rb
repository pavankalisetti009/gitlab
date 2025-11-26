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
        defer_on_database_health_signal :gitlab_main, [:p_ai_active_context_code_enabled_namespaces], 10.minutes

        BATCH_SIZE = 1000

        def handle_event(_)
          return false if ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
          return false unless ::Ai::ActiveContext::Collections::Code.indexing?
          return false unless eligible_instance?

          process_in_batches!
        end

        private

        def eligible_instance?
          return false unless ::License.ai_features_available?
          return false unless ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?

          true
        end

        def process_in_batches!
          total_count = 0

          Namespace.group_namespaces.top_level.each_batch(of: BATCH_SIZE) do |batch|
            namespace_ids = batch.pluck_primary_key
            records_to_insert = collect_eligible_namespaces(namespace_ids)

            next if records_to_insert.empty?

            Ai::ActiveContext::Code::EnabledNamespace.insert_all(
              records_to_insert,
              unique_by: %w[connection_id namespace_id]
            )

            total_count += records_to_insert.size

            break if total_count >= BATCH_SIZE
          end

          log_extra_metadata_on_done(:enabled_namespaces_created, total_count)
        end

        def collect_eligible_namespaces(namespace_ids)
          return [] if namespace_ids.empty?

          eligible_namespace_ids = namespace_ids - existing_namespace_ids(namespace_ids)
          return [] if eligible_namespace_ids.empty?

          eligible_namespace_ids.map do |namespace_id|
            { namespace_id: namespace_id, connection_id: active_connection.id, state: 'ready' }
          end
        end

        def existing_namespace_ids(namespace_ids)
          active_connection.enabled_namespaces.namespace_id_in(namespace_ids).map(&:namespace_id)
        end

        def active_connection
          Ai::ActiveContext::Connection.active
        end
        strong_memoize_attr :active_connection
      end
    end
  end
end
