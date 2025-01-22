# frozen_string_literal: true

module Search
  module Zoekt
    class RepoMarkedAsToDeleteEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories, :zoekt_tasks], 10.minutes

      BATCH_SIZE = 1000

      def handle_event(_event)
        repos = Repository.should_be_deleted.limit(BATCH_SIZE)

        repos.each do |repo|
          # Note: this has checks in place that prevent creating duplicate tasks
          Repository.create_tasks(
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
