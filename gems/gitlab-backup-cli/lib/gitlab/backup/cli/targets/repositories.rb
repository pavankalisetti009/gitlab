# frozen_string_literal: true

require 'yaml'

module Gitlab
  module Backup
    module Cli
      module Targets
        # Backup and restores repositories by querying the database
        class Repositories < Target
          BATCH_SIZE = 1000

          def dump(destination)
            gitaly_backup.start(:create, destination)
            enqueue_consecutive

          ensure
            gitaly_backup.finish!
          end

          def restore(source)
            gitaly_backup.start(:restore, source, remove_all_repositories: remove_all_repositories)
            enqueue_consecutive

          ensure
            gitaly_backup.finish!

            restore_object_pools
          end

          def gitaly_backup
            @gitaly_backup ||= Services::GitalyBackup.new(context)
          end

          private

          def remove_all_repositories
            context.config_repositories_storages.keys
          end

          def enqueue_consecutive
            enqueue_consecutive_projects_source_code
            enqueue_consecutive_projects_wiki
            enqueue_consecutive_groups_wiki
            enqueue_consecutive_project_design_management
            enqueue_consecutive_project_snippets
            enqueue_consecutive_personal_snippets
          end

          def enqueue_consecutive_projects_source_code
            Models::Project.find_each(batch_size: BATCH_SIZE) do |project|
              enqueue_project_source_code(project)
            end
          end

          def enqueue_consecutive_projects_wiki
            Models::ProjectWiki.find_each(batch_size: BATCH_SIZE) do |project_wiki|
              enqueue_wiki(project_wiki)
            end
          end

          def enqueue_consecutive_groups_wiki
            Models::GroupWiki.find_each(batch_size: BATCH_SIZE) do |group_wiki|
              enqueue_wiki(group_wiki)
            end
          end

          def enqueue_consecutive_project_design_management
            Models::ProjectDesignManagement.find_each(batch_size: BATCH_SIZE) do |project_design_management|
              enqueue_project_design_management(project_design_management)
            end
          end

          def enqueue_consecutive_project_snippets
            Models::ProjectSnippet.find_each(batch_size: BATCH_SIZE) do |snippet|
              enqueue_snippet(snippet)
            end
          end

          def enqueue_consecutive_personal_snippets
            Models::PersonalSnippet.find_each(batch_size: BATCH_SIZE) do |snippet|
              enqueue_snippet(snippet)
            end
          end

          def enqueue_project_source_code(project)
            gitaly_backup.enqueue(project, Gitlab::Backup::Cli::RepoType::PROJECT)
          end

          def enqueue_wiki(project_wiki)
            gitaly_backup.enqueue(project_wiki, Gitlab::Backup::Cli::RepoType::WIKI)
          end

          def enqueue_project_design_management(project_design_management)
            gitaly_backup.enqueue(project_design_management, Gitlab::Backup::Cli::RepoType::DESIGN)
          end

          def enqueue_snippet(snippet)
            gitaly_backup.enqueue(snippet, Gitlab::Backup::Cli::RepoType::SNIPPET)
          end

          def restore_object_pools
            pool = Gitlab::Backup::Cli::Utils::PoolRepositories.new(gitlab_basepath: context.gitlab_basepath)
            pool.reinitialize!
          end
        end
      end
    end
  end
end
