# frozen_string_literal: true

module Ai
  module ActiveContext
    class Collection < ApplicationRecord
      self.table_name = :ai_active_context_collections

      validates :name, presence: true, length: { maximum: 255 }
      validates :metadata, json_schema: { filename: 'ai_active_context_collection_metadata' }
      validates :number_of_partitions, presence: true, numericality: { greater_than_or_equal_to: 1, only_integer: true }

      def partition_for(routing_value)
        ::ActiveContext::Hash.consistent_hash(number_of_partitions, routing_value)
      end
    end
  end
end
