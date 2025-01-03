# frozen_string_literal: true

module Search
  module Zoekt
    class RepoMarkedAsToDeleteEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories, :zoekt_tasks], 10.minutes

      def handle_event(event)
        Search::Zoekt::Repository.where(id: event.data[:zoekt_repo_ids]).each_batch do |batch| # rubocop:disable CodeReuse/ActiveRecord -- Not relevant
          batch.each do |repo|
            # Note: this has checks in place that prevent creating duplicate tasks
            Search::Zoekt::Repository.create_tasks(
              project_id: repo.project_identifier,
              zoekt_index: repo.zoekt_index,
              task_type: :delete_repo,
              perform_at: Time.current
            )
          end
        end
      end
    end
  end
end
