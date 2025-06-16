# frozen_string_literal: true

# Constants for the default values
DEFAULT_TOTAL_COUNT = 50
DEFAULT_PROJECT_PATH = 'gitlab-org/gitlab-test'
DEFAULT_CURRENT_USER_COUNT_LIMIT = 24

namespace :gitlab do
  namespace :duo_workflow do
    desc "GitLab | Duo Workflows | Populate fake workflow data"
    # Example usage: bundle exec rake "gitlab:duo_workflow:populate[50,20,user@example.com,gitlab-org/gitlab-test]"
    # total_count: Total workflows to create (default: 50)
    # current_user_count: Workflows for target user (default: min(total_count, 24))
    # user_id: User ID or email (default: first available user)
    # project_path: Project path like 'gitlab-org/gitlab' (default: gitlab-org/gitlab-test)
    # Note: This task cannot be run in production.
    # Note: this current_user_count cannot be greater than total_count

    task :populate, [:total_count, :current_user_count, :user_id, :project_path] => :environment do |_t, args|
      raise 'This task cannot be run in production' if Rails.env.production?

      # Parse and validate total_count argument
      if args.total_count.blank?
        total_count = DEFAULT_TOTAL_COUNT
      else
        total_count = args.total_count.to_i
        if total_count <= 0
          puts Rainbow("Error: total_count must be a positive integer, got: #{args.total_count}").red
          exit 1
        end
      end

      # Default current_user_count to min(total_count, DEFAULT_CURRENT_USER_COUNT_LIMIT) but at least 1
      default_current_user_count = [[total_count, DEFAULT_CURRENT_USER_COUNT_LIMIT].min, 1].max

      # Parse and validate current_user_count argument
      if args.current_user_count.blank?
        current_user_count = default_current_user_count
      else
        current_user_count = args.current_user_count.to_i
        if current_user_count <= 0
          puts Rainbow("Error: current_user_count must be a positive integer, got: #{args.current_user_count}").red
          exit 1
        end
      end

      # Resolve target user
      if args.user_id.present?
        # Try to find by ID first, then by email, then by username
        target_user = if args.user_id.to_s.match?(/\A\d+\z/)
                        User.find_by(id: args.user_id.to_i)
                      else
                        User.find_by(email: args.user_id) || User.find_by(username: args.user_id)
                      end

        if target_user.nil?
          puts Rainbow("Error: User not found with identifier: #{args.user_id}").red
          puts "Try using a valid user ID, email, or username."
          exit 1
        end
      else
        # Use first available user as fallback
        target_user = User.first
        if target_user.nil?
          puts Rainbow("Error: No users found in database. Please create a user first.").red
          exit 1
        end

        puts Rainbow("No user specified, using first available user:
          #{target_user.username} (#{target_user.email})").yellow
      end

      # Resolve target project
      if args.project_path.present?
        target_project = Project.find_by_full_path(args.project_path)

        if target_project.nil?
          puts Rainbow("Error: Project not found with path: #{args.project_path}").red
          puts "Try using a valid project path like 'gitlab-org/gitlab'."
          exit 1
        end
      else
        # Default to gitlab-org/gitlab-test
        default_path = DEFAULT_PROJECT_PATH
        target_project = Project.find_by_full_path(default_path)

        if target_project
          puts Rainbow("No project specified, using default project: #{default_path}").yellow
        else
          # Fall back to first available project if default doesn't exist
          target_project = Project.first
          if target_project.nil?
            puts Rainbow("Error: No projects found in database. Please create a project first.").red
            exit 1
          end

          puts Rainbow("Default project '#{default_path}' not found,
            using first available project: #{target_project.full_path}").yellow
        end
      end

      # Validate arguments
      if current_user_count > total_count
        puts Rainbow("Error: current_user_count (#{current_user_count})
        cannot be greater than total_count (#{total_count})").red
        puts "Usage: rake gitlab:duo_workflows:populate[total_count,current_user_count,user_id,project_path]"
        puts "  total_count: Total workflows to create (default: #{DEFAULT_TOTAL_COUNT})"
        puts "  current_user_count: Workflows for target user (default: min(total_count,
          #{DEFAULT_CURRENT_USER_COUNT_LIMIT}))"
        puts "  user_id: User ID or email (default: first available user)"
        puts "  project_path: Project path like 'gitlab-org/gitlab' (default: #{DEFAULT_PROJECT_PATH})"
        exit 1
      end

      puts "Creating #{total_count} fake Ai::DuoWorkflows::Workflow entities..."
      puts "#{current_user_count} will be assigned to user: #{target_user.username} (#{target_user.email})"
      puts "All workflows will be assigned to project: #{target_project.full_path}"

      # Sample goals for workflows
      sample_goals = [
        "Create a new user authentication system",
        "Implement API rate limiting",
        "Add database migration for user preferences",
        "Fix memory leak in background jobs",
        "Optimize database queries for dashboard",
        "Add unit tests for payment processing",
        "Implement OAuth2 integration",
        "Create automated deployment pipeline",
        "Add logging and monitoring",
        "Refactor legacy code modules",
        "Implement caching layer",
        "Add email notification system",
        "Create admin dashboard",
        "Fix security vulnerabilities",
        "Add mobile API endpoints",
        "Implement search functionality",
        "Add data export feature",
        "Create backup and restore system",
        "Implement real-time notifications",
        "Add multi-language support",
        "Optimize frontend performance",
        "Add GraphQL API endpoints",
        "Implement file upload system",
        "Create user onboarding flow",
        "Add two-factor authentication",
        "Implement role-based permissions",
        "Create reporting dashboard",
        "Add webhook integration",
        "Implement data validation",
        "Create API documentation"
      ]

      # Sample workflow definitions
      workflow_definitions = %w[software_development chat convert_to_gitlab_ci]

      # Sample statuses (using the state machine values)
      statuses = [0, 1, 2, 3, 4, 5, 6, 7, 8]

      # Get some existing users for associations, excluding the target user
      users = User.where.not(id: target_user.id).limit(10).pluck(:id)

      if users.empty?
        puts Rainbow("Warning: No other users found besides target user. Creating a test user...").yellow
        user = User.create!(
          email: "test-workflow-user@example.com",
          username: "workflow-test-user",
          name: "Workflow Test User",
          password: "password123",
          password_confirmation: "password123"
        )
        users = [user.id]

      end

      workflows_created = 0
      errors = []

      total_count.times do |i|
        # Random agent privileges (using the constants from the model)
        available_privileges = [
          Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
          Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
          Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
          Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
          Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT
        ]

        # Select 2-4 random privileges
        agent_privileges = available_privileges.sample(rand(2..4))

        # Pre-approved privileges should be a subset of agent privileges
        pre_approved_privileges = agent_privileges.sample(rand(1..agent_privileges.length))

        # Determine user_id: use target user for first current_user_count workflows
        user_id = if i < current_user_count
                    target_user.id
                  else
                    users.sample
                  end

        Ai::DuoWorkflows::Workflow.create!(
          user_id: user_id,
          project_id: target_project.id,
          goal: "#{sample_goals.sample} (Workflow ##{i + 1})",
          status: statuses.sample,
          workflow_definition: workflow_definitions.sample,
          agent_privileges: agent_privileges,
          pre_approved_agent_privileges: pre_approved_privileges,
          allow_agent_to_request_user: [true, false].sample
        )

        workflows_created += 1
        print "." if (i + 1) % 10 == 0

      rescue StandardError => e
        errors << "Error creating workflow #{i + 1}: #{e.message}"
      end

      puts "\n\nSuccessfully created #{workflows_created} Ai::DuoWorkflows::Workflow entities!"
      puts "#{current_user_count} workflows assigned to target user (#{target_user.username})"
      puts "#{workflows_created - current_user_count} workflows assigned to other users"
      puts "Total workflows in database: #{Ai::DuoWorkflows::Workflow.count}"

      if errors.any?
        puts "\nErrors encountered:"
        errors.each { |error| puts Rainbow("  - #{error}").red }
      end
    end
  end
end
