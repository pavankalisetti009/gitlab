# frozen_string_literal: true

module Search
  module Zoekt
    class TaskSucceededEvent < ::Gitlab::EventStore::Event
      def schema
        {
          'type' => 'object',
          'properties' => {
            'zoekt_repository_id' => { 'type' => 'integer' },
            'task_id' => { 'type' => 'integer' }
          },
          'required' => %w[zoekt_repository_id task_id]
        }
      end
    end
  end
end
