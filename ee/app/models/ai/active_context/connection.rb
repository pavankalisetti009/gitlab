# frozen_string_literal: true

module Ai
  module ActiveContext
    class Connection < ApplicationRecord
      self.table_name = :ai_active_context_connections

      ADAPTERS_FOR_ADVANCED_SEARCH = {
        elasticsearch: ::ActiveContext::Databases::Elasticsearch::Adapter,
        opensearch: ::ActiveContext::Databases::Opensearch::Adapter
      }.freeze

      has_many :collections, class_name: 'Ai::ActiveContext::Collection'

      encrypts :options

      has_many :migrations, class_name: 'Ai::ActiveContext::Migration'
      has_many :enabled_namespaces, class_name: 'Ai::ActiveContext::Code::EnabledNamespace',
        inverse_of: :active_context_connection
      has_many :repositories, class_name: 'Ai::ActiveContext::Code::Repository', inverse_of: :active_context_connection

      validates :name, presence: true, length: { maximum: 255 }, uniqueness: true
      validates :adapter_class, presence: true, length: { maximum: 255 }
      validates :prefix, length: { maximum: 255 }, allow_nil: true
      validates :active, inclusion: { in: [true, false] }
      validates :options, presence: true
      validates_uniqueness_of :active, conditions: -> { where(active: true) }, if: :active

      after_destroy :reload_adapter
      after_save :reload_adapter
      after_commit :process_deactivation_async, on: :update, if: :saved_change_to_active?

      def self.active
        where(active: true).first
      end

      # Find connection by id. Defaults to active connection.
      def self.find_connection(id = nil)
        if id
          find_by(id: id)
        else
          active
        end
      end

      # Activates this connection and deactivates the previously active connection.
      # Note: deactivate! is destructive - it drops all associated and indexed data
      def activate!
        return if active?

        self.class.transaction do
          self.class.active&.deactivate!
          update!(active: true)
        end
      end

      # Deactivates the connection by marking as inactive.
      # This enqueues an async worker that will:
      # 1. Drop collections from the external service (Elasticsearch/OpenSearch)
      # 2. Delete the connection record (which triggers loose FK async cleanup of repositories)
      # Associated repositories are cleaned up asynchronously via loose foreign key.
      def deactivate!
        return unless active?

        update!(active: false)
      end

      def options
        opts = if use_advanced_search_config?
                 ::Gitlab::CurrentSettings.elasticsearch_config
               else
                 super
               end

        # The prefix enables connection-specific index isolation for different environments
        opts[:prefix] = prefix if prefix.present?
        opts
      end

      def use_advanced_search_config?
        ADAPTERS_FOR_ADVANCED_SEARCH.value?(adapter_class&.safe_constantize) &&
          use_advanced_search_config_option == true
      end

      def use_advanced_search_config_option
        read_attribute(:options)['use_advanced_search_config']
      end

      def adapter
        ::ActiveContext::Adapter.for_connection(self)
      end

      def reload_adapter
        ::ActiveContext::Adapter.reset
      end

      private

      def process_deactivation_async
        return if active?

        ::Ai::ActiveContext::ConnectionCleanupWorker.perform_async(id)
      end
    end
  end
end
