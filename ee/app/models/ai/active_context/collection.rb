# frozen_string_literal: true

module Ai
  module ActiveContext
    class Collection < ApplicationRecord
      self.table_name = :ai_active_context_collections

      jsonb_accessor :metadata,
        include_ref_fields: :boolean,
        indexing_embedding_versions: [:integer, { array: true }],
        search_embedding_version: :integer,
        collection_class: :string

      jsonb_accessor :options,
        queue_shard_count: :integer,
        queue_shard_limit: :integer

      belongs_to :connection, class_name: 'Ai::ActiveContext::Connection'

      validates :name, presence: true, length: { maximum: 255 }
      validates :name, uniqueness: { scope: :connection_id }
      validates :metadata, json_schema: { filename: 'ai_active_context_collection_metadata', size_limit: 16.kilobytes }
      validates :options, json_schema: { filename: 'ai_active_context_collection_options', size_limit: 2.kilobytes }
      validates :number_of_partitions, presence: true, numericality: { greater_than_or_equal_to: 1, only_integer: true }
      validates :connection_id, presence: true

      def self.find_by_id(connection, id)
        connection.collections.find_by(id: id)
      end

      def self.find_by_name(connection, name)
        connection.collections.find_by(name: name)
      end

      def partition_for(routing_value)
        ::ActiveContext::Hasher.consistent_hash(number_of_partitions, routing_value)
      end

      def update_metadata!(new_metadata)
        update!(metadata: metadata.merge(new_metadata))
      end

      def update_options!(new_options)
        update!(options: options.merge(new_options))
      end
    end
  end
end
