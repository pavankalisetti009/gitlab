# frozen_string_literal: true

module Search
  module Zoekt
    class RepoToIndexEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      idempotent!

      def handle_event(event)
        Repository.id_in(event.data[:zoekt_repo_ids]).pending_or_initializing.each do |repository|
          next if repository.project.nil?

          if repository.project.empty_repo?
            repository.ready!
            next
          end

          ::Search::Zoekt.index_async(repository.project_identifier)
        end
      end
    end
  end
end
