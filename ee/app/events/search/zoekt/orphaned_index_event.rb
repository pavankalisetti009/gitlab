# frozen_string_literal: true

module Search
  module Zoekt
    class OrphanedIndexEvent < ::Gitlab::EventStore::Event
      def schema
        {
          'type' => 'object',
          'properties' => {
            'index_ids' => { 'type' => 'array', 'items' => { 'type' => 'integer' } }
          },
          'required' => %w[index_ids]
        }
      end
    end
  end
end
