# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class SweBenchSeeder
        class IssueManager
          def self.create_issue_from_problem_statement(project, user, problem_statement, base_commit)
            return if problem_statement.blank?

            # Extract first line as title and remove it from description
            lines = problem_statement.split("\n")
            title = lines.first.strip
            description = lines[1..].join("\n").strip

            # Append base commit information if provided
            if base_commit.present?
              description += "\n\n**To reproduce this issue, checkout the commit:** `#{base_commit}`"
            end

            # Delete existing issue with the same title if it exists
            existing_issue = project.issues.find_by_title(title)
            if existing_issue
              puts "Issue '#{title}' already exists. Deleting it..."
              ::Issues::DestroyService.new(container: project, current_user: user).execute(existing_issue)
              puts "Deleted existing issue."
            end

            puts "\nCreating issue from problem statement..."
            puts "Title: #{title}"

            Sidekiq.strict_args!(false)
            result = ::Issues::CreateService.new(
              container: project,
              current_user: user,
              params: {
                title: title,
                description: description
              }
            ).execute

            unless result.success?
              puts "Failed to create issue '#{title}': #{result.errors.join(', ')}"
              return
            end

            issue = result.payload[:issue]
            issue_url = Rails.application.routes.url_helpers.project_issue_url(project, issue)
            puts "Created issue: #{issue_url}"

            # Create branch for the issue if base_commit is provided
            create_issue_branch(project, issue, base_commit, user) if base_commit.present?

            issue
          rescue StandardError => e
            puts "Error creating issue: #{e.message}"
            puts e.backtrace.first(5).join("\n")
            nil
          end

          def self.create_issue_branch(project, issue, base_commit, user)
            target_branch = "issue-#{issue.iid}"
            source_branch = "fix-issue-#{issue.iid}"

            puts "Creating branch pair '(#{target_branch}, #{source_branch})' from commit '#{base_commit}'..."

            project.repository.add_branch(user, target_branch, base_commit)
            project.repository.add_branch(user, source_branch, base_commit)

            puts "Created branch: #{target_branch}"
          rescue StandardError => e
            if e.message.include?('already exists')
              puts "Branch '#{target_branch}' already exists"
            else
              puts "Error creating branch: #{e.message}"
              puts e.backtrace.first(5).join("\n")
            end
          end

          def self.delete_all_issues_in_subgroup(subgroup, user)
            puts "\nDeleting all existing issues in subgroup #{subgroup.full_path}..."
            total_deleted = 0
            total_projects_deleted = 0

            # Iterate through all projects in the subgroup
            subgroup.all_projects.find_each do |project|
              project_deleted = 0
              project.issues.find_each do |issue|
                ::Issues::DestroyService.new(container: project, current_user: user).execute(issue)
                project_deleted += 1
                total_deleted += 1
              rescue StandardError => e
                puts "Failed to delete issue '#{issue.title}' in #{project.full_path}: #{e.message}"
              end
              puts "Deleted #{project_deleted} issue(s) from #{project.full_path}" if project_deleted > 0

              # Also delete the project itself so subsequent seeding starts from a clean slate.
              if ::Projects::MarkForDeletionService.new(project, user, {}).execute
                total_projects_deleted += 1
                puts "Deleted project: #{project.full_path}"
              else
                puts "Failed to delete project #{project.full_path} (insufficient permissions or admin-mode required)"
              end
            rescue StandardError => e
              puts "Failed to delete project #{project.full_path}: #{e.message}"
            end

            puts "Deleted #{total_deleted} total issue(s) from subgroup.\n" if total_deleted > 0
            puts "Deleted #{total_projects_deleted} total project(s) from subgroup.\n" if total_projects_deleted > 0
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

            puts "Deleted #{deleted_count} issues.\n" if deleted_count > 0
          end
        end
      end
    end
  end
end
