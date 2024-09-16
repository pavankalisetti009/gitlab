# frozen_string_literal: true

module Search
  module Zoekt
    class IndexOverWatermarkEvent < ::Gitlab::EventStore::Event
      def schema
        {
          'type' => 'object',
          'properties' => {
            'index_ids' => { 'type' => 'array', 'items' => { 'type' => 'integer' } },
            'watermark' => { 'type' => 'number' }
          },
          'required' => %w[index_ids watermark]
        }
      end
    end
  end
end
