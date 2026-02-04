# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class SweBenchSeeder
        require_relative 'swe_bench_seeder/config'
        require_relative 'swe_bench_seeder/group_manager'
        require_relative 'swe_bench_seeder/repository_manager'
        require_relative 'swe_bench_seeder/issue_manager'
        require_relative 'swe_bench_seeder/dataset_processor'
        require_relative 'swe_bench_seeder/langsmith_client'

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, -- Main orchestration method with multiple responsibilities
        def self.seed(project_filter: nil)
          puts "Seeding SWE Bench data structure..."
          puts "Filtering to projects: #{project_filter.join(', ')}" if project_filter

          user = User.find_by_username('root')
          parent_group = GroupManager.find_or_create_parent_group(user)
          subgroup = GroupManager.find_or_create_subgroup(parent_group, user)

          puts "Subgroup URL: #{Config.seed_base_url}/#{subgroup.full_path}"

          # Delete all existing issues in the subgroup
          IssueManager.delete_all_issues_in_subgroup(subgroup, user)

          # Fetch and process examples from LangSmith dataset
          dataset, _dataset_name, _split_name = DatasetProcessor.fetch_dataset_from_langsmith
          return if dataset.empty?

          puts "\n=== Processing examples from SWE Bench Dataset ==="
          puts "==========================================\n"

          # Statistics tracking
          projects_created = 0
          issues_per_project = {}
          created_issue_urls = []
          issue_data = [] # Track issue URLs with their base_commit

          # Group examples by repository
          examples_by_repo = DatasetProcessor.group_examples_by_repo(dataset)

          # Filter by project if specified
          examples_by_repo = DatasetProcessor.filter_by_project(examples_by_repo, project_filter)

          total_examples = examples_by_repo.values.sum(&:size)
          puts "Found #{examples_by_repo.keys.size} unique repositories with #{total_examples} total examples\n"

          # Process each repository
          examples_by_repo.each_with_index do |(repo, examples), repo_index|
            repo_msg = "#{repo_index + 1}/#{examples_by_repo.keys.size}: #{repo} (#{examples.size} issue(s))"
            puts "\n--- Processing repository #{repo_msg} ---"

            repository_url = "#{Config.source_base_url}/#{repo}.git"
            puts "Repo URL: #{repository_url}"

            # Create or recreate the project once for all issues
            project = RepositoryManager.clone_repository(repository_url, repo, subgroup, user)

            next unless project&.persisted?

            # Track project creation (count if it was newly created or recreated)
            projects_created += 1

            # Initialize issue count for this project
            issues_per_project[project.full_path] = 0

            # Create all issues for this project
            examples.each_with_index do |example, example_index|
              puts "\n  Creating issue #{example_index + 1}/#{examples.size} for #{project.full_path}..."

              next unless example['inputs']['problem_statement']

              issue = IssueManager.create_issue_from_problem_statement(
                project, user, example['inputs']['problem_statement'],
                example['inputs']['base_commit']
              )
              next unless issue

              issues_per_project[project.full_path] += 1
              issue_url = Rails.application.routes.url_helpers.project_issue_url(project, issue)
              created_issue_urls << issue_url

              # Generate source branch name (same as in create_issue_branch)
              source_branch = "issue-#{issue.iid}"

              issue_data << {
                inputs: {
                  issue_url: issue_url,
                  source_branch: source_branch,
                  **example['inputs']
                },
                outputs: example['outputs']
              }
            end
          end

          # Print statistics
          total_issues = issues_per_project.values.sum
          puts "\n#{'=' * 60}"
          puts "SEEDING STATISTICS"
          puts "=" * 60
          puts "Total projects created: #{projects_created}"
          puts "Total projects processed: #{issues_per_project.keys.size} (#{total_issues} issue(s) total)"
          puts "\nIssues per project:"
          issues_per_project.each do |project_path, issue_count|
            puts "  #{project_path}: #{issue_count} issue(s)"
          end
          puts "=" * 60

          # Save issue URLs to LangSmith dataset only if SAVE_TO_LANGSMITH is set
          save_to_langsmith = ENV['SAVE_TO_LANGSMITH'].presence
          save_issue_urls_to_langsmith(issue_data, save_to_langsmith) if save_to_langsmith.present? && issue_data.any?
        rescue StandardError => e
          puts "Error seeding SWE Bench structure: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          raise
        end

        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

        # Wrapper method for backward compatibility with tests
        def self.save_issue_urls_to_langsmith(issue_data, dataset_name)
          LangsmithClient.save_issue_urls_to_langsmith(issue_data, dataset_name)
        end
      end
    end
  end
end
