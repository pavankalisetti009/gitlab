# frozen_string_literal: true

module Search
  module Zoekt
    class RepoMarkedAsToDeleteEvent < ::Gitlab::EventStore::Event
      def schema
        {
          'type' => 'object',
          'properties' => {
            'zoekt_repo_ids' => { 'type' => 'array', 'items' => { 'type' => 'integer' } }
          },
          'required' => %w[zoekt_repo_ids]
        }
      end
    end
  end
end
