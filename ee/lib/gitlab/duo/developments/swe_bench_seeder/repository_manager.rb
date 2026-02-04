# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class SweBenchSeeder
        class RepositoryManager
          def self.clone_repository(repository_url, repo_path, subgroup, user)
            puts "\nCloning repository from #{repository_url}..."

            project_name = repo_path.split('/').last
            project_full_path = "#{subgroup.full_path}/#{project_name}"
            existing_project = Project.find_by_full_path(project_full_path)

            if existing_project
              puts "Project #{project_full_path} already exists. Deleting it..."
              IssueManager.delete_all_issues(existing_project, user)
              ::Projects::MarkForDeletionService.new(existing_project, user).execute
              puts "Deleted existing project."
            end

            puts "Creating project #{project_name} in #{subgroup.full_path}..."

            project_params = {
              name: project_name,
              path: project_name,
              namespace_id: subgroup.id,
              import_url: repository_url,
              visibility_level: subgroup.visibility_level,

              # a few settings to speed up the import.
              import_data: {
                data: {
                  timeout_strategy: 'optimistic' # Faster than default 'pessimistic'
                },
                optional_stages: {
                  attachments_import: false, # Skip file attachments
                  collaborators_import: false, # Skip collaborator import
                  single_endpoint_notes_import: true # Faster comment import
                }
              }
            }

            project = ::Projects::CreateService.new(user, project_params).execute

            if project.errors.any?
              puts "Failed to create project: #{project.errors.full_messages.join(', ')}"
              return
            end

            unless project.persisted?
              puts "Failed to create project: Project was not saved"
              return
            end

            puts "Created project: #{project.full_path}"
            puts "Project URL: #{Config.seed_base_url}/#{project.full_path}"

            # Wait for repository import to complete
            wait_for_repository_import(project)

            project
          rescue StandardError => e
            puts "Error cloning repository: #{e.message}"
            puts e.backtrace.first(5).join("\n")
            nil
          end

          def self.wait_for_repository_import(project, max_wait_seconds: 600)
            start_time = Time.current
            check_interval = 1

            loop do
              project.reset

              # Check import state
              import_state = project.import_state
              status = import_state&.status
              failed = import_state&.failed?
              finished = import_state&.finished?

              # Check if repository exists
              repo_exists = project.repository_exists?

              elapsed = Time.current - start_time

              puts "Waiting for repository import... (#{elapsed.round(1)}s elapsed) - status=#{status}"

              if repo_exists
                puts "Repository import completed successfully (took #{elapsed.round(2)}s)"
                return true
              end

              # Check if import failed
              if failed
                puts "Repository import failed: #{import_state.last_error}"
                return false
              end

              # Check if import is finished (success status)
              if finished
                puts "Repository import finished (took #{elapsed.round(2)}s)"
                return true
              end

              if elapsed > max_wait_seconds
                puts "Repository import timeout after #{max_wait_seconds} seconds"
                return false
              end

              sleep(check_interval)
            end
          rescue StandardError => e
            puts "Error waiting for repository import: #{e.message}"
            puts e.backtrace.first(5).join("\n")
            false
          end
        end
      end
    end
  end
end
