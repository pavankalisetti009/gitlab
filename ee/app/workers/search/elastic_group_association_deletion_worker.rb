# frozen_string_literal: true

module Search
  class ElasticGroupAssociationDeletionWorker
    include ApplicationWorker
    include Search::Worker
    prepend ::Elastic::IndexingControl
    prepend ::Geo::SkipSecondary

    MAX_JOBS_PER_HOUR = 3600

    sidekiq_options retry: 3
    data_consistency :delayed
    urgency :throttled
    idempotent!

    def perform(group_id, ancestor_id, options = {})
      return unless Gitlab::CurrentSettings.elasticsearch_indexing?

      group = Group.find_by_id(group_id)
      remove_epics = index_epics?(group)

      options = options.with_indifferent_access
      return process_removal(group_id, ancestor_id, remove_epics: remove_epics) unless options[:include_descendants]

      # We have the return condition here because we still want to remove the deleted items in the above call
      return if group.nil?

      # rubocop: disable CodeReuse/ActiveRecord -- We need only the ids of self_and_descendants groups
      group.self_and_descendants.each_batch do |groups|
        process_removal(groups.pluck(:id), ancestor_id, remove_epics: remove_epics)
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end

    private

    def client
      @client ||= ::Gitlab::Search::Client.new
    end

    def index_epics?(group)
      return true unless group.present?

      group.licensed_feature_available?(:epics)
    end

    def process_removal(group_id, ancestor_id, remove_epics:)
      remove_items(group_id, ancestor_id, index_name: ::Search::Elastic::Types::WorkItem.index_name,
        group_id_field: :namespace_id)

      return unless remove_epics

      remove_items(group_id, ancestor_id, index_name: ::Elastic::Latest::EpicConfig.index_name,
        group_id_field: :group_id)
    end

    def remove_items(group_ids, ancestor_id, index_name:, group_id_field:)
      terms_hash = Hash[group_id_field, Array.wrap(group_ids)].deep_symbolize_keys
      client.delete_by_query(
        {
          index: index_name,
          routing: "group_#{ancestor_id}",
          conflicts: 'proceed',
          timeout: '10m',
          body: {
            query: {
              bool: {
                filter: { terms: terms_hash }
              }
            }
          }
        }
      )
    end
  end
end
