# frozen_string_literal: true

require 'yaml'

module Gitlab
  module Backup
    module Cli
      module Targets
        # Backup and restores repositories by querying the database
        class Repositories < Target
          PoolReinitializationResult = Struct.new(:disk_path, :status, :error_message, keyword_init: true)

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
            gitlab_path = context.gitlab_basepath

            Gitlab::Backup::Cli::Output.info "Reinitializing object pools..."

            rake = Gitlab::Backup::Cli::Utils::Rake.new(
              'gitlab:backup:repo:reset_pool_repositories',
              chdir: gitlab_path)

            rake.capture_each do |stream, output|
              next Gitlab::Backup::Cli::Output.error output if stream == :stderr

              pool = parse_pool_results(output)
              next Gitlab::Backup::Cli::Output.warn "Failed to parse: #{output}" unless pool

              case pool.status.to_sym
              when :scheduled
                Gitlab::Backup::Cli::Output.success "Object pool #{pool.disk_path}..."
              when :skipped
                Gitlab::Backup::Cli::Output.info "Object pool #{pool.disk_path}... [SKIPPED]"
              when :failed
                Gitlab::Backup::Cli::Output.info "Object pool #{pool.disk_path}... [FAILED]"
                Gitlab::Backup::Cli::Output.error(
                  "Object pool #{pool.disk_path} failed to reset (#{pool.error_message})")
              end
            end
          end

          def parse_pool_results(line)
            return unless line.start_with?('{') && line.end_with?('}')

            JSON.parse(line, object_class: PoolReinitializationResult)
          rescue JSON::ParserError
            nil
          end
        end
      end
    end
  end
end
