# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class DapEvalsSeeder
        GROUP_PATH = 'gitlab-duo'
        PROJECT_PATH = 'test'

        ISSUES_TO_CREATE = [
          {
            title: 'Rename MyHandler to MyCustomHandler',
            description: <<~DESC
              The python class MyHandler should be renamed to MyCustomHandler to match new developments.
              Do not create commits to the main branch.
              First create a new branch and then create a MR from it.
            DESC
          },
          {
            title: 'Add docstrings to all python classes and functions in python/server.py',
            description: <<~DESC
              All python classes in the project must have docstrings following PEP 257 conventions.
              Each class should have a brief description of its purpose and functionality.
            DESC
          },
          {
            title: 'Add error handling for invalid HTTP methods in server.py',
            description: <<~DESC
              The HTTP server in server.py should return a proper 405 Method Not Allowed response
              when receiving unsupported HTTP methods instead of crashing or returning a generic error.
            DESC
          },
          {
            title: 'Add request logging functionality to server.py',
            description: <<~DESC
              Implement basic request logging in server.py that logs incoming requests with timestamp,
              method, path, and response status code to help with debugging and monitoring.
            DESC
          },
          {
            title: 'Add configuration file support for server port and host',
            description: <<~DESC
              Replace hardcoded server configuration in server.py with support for a config file
              (JSON or YAML) that allows setting host, port, and other server parameters
              without modifying the code.
            DESC
          },
          {
            title: 'Implement graceful shutdown handling in server.py',
            description: <<~DESC
              Add signal handling (SIGTERM, SIGINT) to server.py to allow graceful shutdown
              that properly closes connections and cleans up resources before terminating.
            DESC
          }
        ].freeze

        def self.seed_issues(output_file: 'dap_evaluation_issues.yml')
          puts "Seeding DAP evaluation issues..."

          source_project = find_project
          user = find_root_user

          # Clone the project with a unique name
          cloned_project = clone_project(source_project, user)
          puts "Cloned project: #{cloned_project.full_path}"

          created_issue_urls = []

          created_count = 0
          skipped_count = 0

          ISSUES_TO_CREATE.each do |issue_data|
            if issue_already_exists?(cloned_project, issue_data[:title])
              puts "Issue '#{issue_data[:title]}' already exists in #{cloned_project.full_path}. Skipping creation."
              skipped_count += 1
              next
            end

            issue = create_issue(cloned_project, user, issue_data)
            issue_url = Rails.application.routes.url_helpers.project_issue_url(cloned_project, issue)
            puts "Created issue: #{issue_url}"

            # Collect issue URL for YAML export
            created_issue_urls << issue_url
            created_count += 1
          end

          # Save to YAML file
          save_issue_urls_to_yaml(created_issue_urls, output_file) if created_issue_urls.any?

          puts "Summary: Created #{created_count} issues, skipped #{skipped_count} existing issues."
          puts "Issue URLs saved to: #{output_file}" if created_issue_urls.any?
        rescue StandardError => e
          puts "Error seeding DAP evaluation issues: #{e.message}"
          raise
        end

        def self.find_project
          project = Project.find_by_full_path("#{GROUP_PATH}/#{PROJECT_PATH}")

          unless project
            raise <<~MSG
              Project '#{GROUP_PATH}/#{PROJECT_PATH}' not found.
              Please run 'rake gitlab:duo:setup' first to create the required project.
            MSG
          end

          project
        end

        def self.find_root_user
          user = User.find_by_username('root')

          raise "Root user not found. Please ensure the development environment is properly set up." unless user

          user
        end

        def self.clone_project(source_project, user)
          # Use fixed project name
          cloned_project_name = "test-issue-to-mr-eval"

          # Find or create the gitlab-duo group
          group = Group.find_by_full_path(GROUP_PATH)
          raise "Group '#{GROUP_PATH}' not found. Please ensure it exists before cloning." unless group

          # Check if project with this name already exists and delete it
          existing_project = Project.find_by_full_path("#{GROUP_PATH}/#{cloned_project_name}")
          if existing_project
            puts "Project #{GROUP_PATH}/#{cloned_project_name} already exists. Deleting it..."
            ::Projects::MarkForDeletionService.new(existing_project, user).execute
            puts "Deleted existing project."
          end

          # Fork the project using the Projects::ForkService
          fork_params = {
            namespace: group,
            name: cloned_project_name,
            path: cloned_project_name,
            description: "Project for DAP evaluation - #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}",
            branches: 'main'
          }

          result = ::Projects::ForkService.new(source_project, user, fork_params).execute

          raise "Failed to fork project: #{result.message}" unless result.success?

          cloned_project = result.payload[:project]
          puts "Successfully forked project to: #{cloned_project.full_path}"
          cloned_project
        end

        def self.issue_already_exists?(project, title)
          project.issues.find_by_title(title).present?
        end

        def self.create_issue(project, user, issue_data)
          Sidekiq.strict_args!(false)
          result = ::Issues::CreateService.new(
            container: project,
            current_user: user,
            params: {
              title: issue_data[:title],
              description: issue_data[:description]
            }
          ).execute

          raise "Failed to create issue '#{issue_data[:title]}': #{result.errors.join(', ')}" unless result.success?

          result.payload[:issue]
        end

        def self.delete_all_issues(project, user)
          puts "Deleting all existing issues..."
          deleted_count = 0

          project.issues.find_each do |issue|
            ::Issues::DestroyService.new(container: project, current_user: user).execute(issue)
            deleted_count += 1
            puts "Deleted issue: '#{issue.title}'"
          rescue StandardError => e
            puts "Failed to delete issue '#{issue.title}': #{e.message}"
          end

          puts "Deleted #{deleted_count} issues.\n"
        end

        def self.save_issue_urls_to_yaml(issue_urls, output_file)
          require 'yaml'

          data = { "issues" => issue_urls }

          File.write(output_file, data.to_yaml)
        rescue StandardError => e
          puts "Warning: Failed to save issue URLs to YAML file: #{e.message}"
        end
      end
    end
  end
end
