# frozen_string_literal: true

class DataSeeder
  NUM_MERGE_REQUESTS = ENV['NUM_MERGE_REQUESTS_TO_SEED'].to_i
  NUM_COMMITS_PER_MR = ENV['NUM_COMMITS_PER_MR_TO_SEED'].to_i

  def seed
    puts "################### CREATING USER WITH FACTORY ###################"
    @user = create_user_with_factory

    puts "################### CREATING THE GROUP WITH FACTORY ###################"
    @group = create_group_with_factory

    puts "################### CREATING THE PROJECT WITH FACTORY ###################"
    @project = create_project_with_factory

    puts "################### CREATING THE REPOSITORY WITH FACTORY ###################"
    create_repository_for_project

    puts "################### CREATING THE GROUP LABELS WITH FACTORY ###################"
    create_group_labels_with_factories

    puts "########### CREATING #{NUM_MERGE_REQUESTS} MERGE REQUESTS WITH #{NUM_COMMITS_PER_MR} COMMITS EACH ###########"
    create_multiple_merge_requests_with_factory
  end

  private

  def create_user_with_factory
    existing_user = User.find_by(username: 'test_seed_dev') # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
    if existing_user
      puts 'Using existing test seed user'
      return existing_user
    end

    user = create(:user,
      name: 'Test Seed Developer',
      username: 'test_seed_dev',
      email: "test_seed_dev_#{SecureRandom.hex(8)}@example.com"
    )
    puts 'Created test seed user'
    user
  end

  def create_group_with_factory
    # Use fixed path for idempotency - allows re-running the seed
    group_path = 'test-seed-group'

    existing_group = Group.find_by(path: group_path) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
    if existing_group
      puts 'Using existing test seed group'
      return existing_group
    end

    group = create(:group,
      name: 'Test Seed Group',
      path: group_path,
      description: 'A group for Test Seed testing',
      visibility_level: Gitlab::VisibilityLevel::PRIVATE
    )

    group.add_owner(@user)
    puts 'Created test seed group'
    group
  end

  def create_project_with_factory
    # Use fixed path for idempotency - allows re-running the seed
    project_path = 'test-seed-project'

    existing_project = @group.projects.find_by(path: project_path) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
    if existing_project
      puts 'Using existing test seed project'
      return existing_project
    end

    project = create(:project,
      name: 'Test Seed Project',
      path: project_path,
      namespace: @group,
      description: 'A test project for Test Seed with dummy repository',
      visibility_level: Gitlab::VisibilityLevel::PRIVATE,
      creator: @user
    )
    puts 'Created test seed project'
    project
  end

  def create_repository_for_project
    if @project.repository_exists?
      puts 'Repository already exists'
      return
    end

    @project.create_repository
    puts 'Created repository'

    # Add user to project with developer access before creating files
    @project.add_developer(@user) unless @project.member?(@user)

    # Verify the user's email so commits pass the commit_committer_check push rule
    @user.emails.update_all(confirmed_at: Time.current)
    # Create initial commit using skip_ci flag to bypass pre-receive hooks
    create_initial_commit_with_skip_ci
  end

  def create_initial_commit_with_skip_ci
    # Use system/admin user to bypass SSH key requirement
    @project.repository.raw_repository.commit_files(
      system_user,
      branch_name: default_branch,
      message: 'Initial commit',
      actions: [
        {
          action: :create,
          file_path: 'README.md',
          content: "# #{@project.name}\n\nWelcome to test seed Project!"
        }
      ],
      force: true
    )
    puts 'Created initial commit'
  rescue Gitlab::Git::CommandError => e
    puts "Failed to create initial commit, error: #{e.message}"
    exit(1)
  end

  def default_branch
    @default_branch ||= @project.default_branch || 'main'
  end

  def system_user
    @system_user ||= User.find_by(username: 'root') || User.admins.first # rubocop:disable CodeReuse/ActiveRecord,Style/InlineDisableAnnotation
  end

  def create_group_labels_with_factories
    labels_data = [
      { title: 'priority::1', color: '#FF0000' },
      { title: 'priority::2', color: '#DD0000' },
      { title: 'priority::3', color: '#CC0000' },
      { title: 'priority::4', color: '#CC1111' }
    ]

    labels_data.each do |label_data|
      create_group_label_with_factory(label_data[:title], label_data[:color])
    end
  end

  def create_group_label_with_factory(title, color)
    return if @group.labels.exists?(title: title) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn

    create(:group_label,
      group: @group,
      title: title,
      color: color
    )
  end

  def create_multiple_merge_requests_with_factory
    NUM_MERGE_REQUESTS.times do |mr_index|
      mr_number = mr_index + 1
      branch_name = "feature/test-seed-feature-#{mr_number}"

      # Check if MR already exists
      existing_mr = @project.merge_requests.find_by(source_branch: branch_name) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
      if existing_mr
        puts "Merge request #{mr_number} already exists"
        next
      end

      puts "Creating merge request #{mr_number}/#{NUM_MERGE_REQUESTS}..."

      # Create feature branch with multiple commits
      create_feature_branch_with_multiple_commits(branch_name, mr_number)

      # Create merge request
      create(:merge_request,
        title: "Add test seed feature #{mr_number} implementation",
        description: "This MR adds feature #{mr_number} for test seed with documentation and tests",
        source_project: @project,
        target_project: @project,
        source_branch: branch_name,
        target_branch: @project.default_branch || 'main',
        author: @user
      )
      puts "Created merge request #{mr_number}"
    end
  end

  def create_feature_branch_with_multiple_commits(branch_name, mr_number)
    if @project.repository.branch_exists?(branch_name)
      puts "Feature branch #{branch_name} already exists"
      return
    end

    # Create initial commit with feature class
    @project.repository.raw_repository.commit_files(
      system_user,
      branch_name: branch_name,
      start_branch_name: default_branch,
      message: "Add TestSeedFeature#{mr_number} class",
      actions: [
        {
          action: :create,
          file_path: "lib/test_seed_feature_#{mr_number}.rb",
          content: <<~RUBY
            # frozen_string_literal: true

            class TestSeedFeature#{mr_number}
              def initialize(name)
                @name = name
              end

              def greet
                "Hello, \#{@name}! This is test seed feature #{mr_number}."
              end
            end
          RUBY
        }
      ],
      force: true
    )

    # Create additional commits (NUM_COMMITS_PER_MR - 1 more commits)
    (NUM_COMMITS_PER_MR - 1).times do |commit_index|
      commit_number = commit_index + 2
      @project.repository.raw_repository.commit_files(
        system_user,
        branch_name: branch_name,
        message: "Add commit #{commit_number} for feature #{mr_number}",
        actions: [
          {
            action: :create,
            file_path: "lib/test_seed_feature_#{mr_number}_commit_#{commit_number}.rb",
            content: <<~RUBY
              # frozen_string_literal: true

              class TestSeedFeature#{mr_number}Commit#{commit_number}
                def self.description
                  "This is commit #{commit_number} for feature #{mr_number}"
                end
              end
            RUBY
          }
        ],
        force: true
      )
    end

    # Add test file as final commit
    @project.repository.raw_repository.commit_files(
      system_user,
      branch_name: branch_name,
      message: "Add tests for TestSeedFeature#{mr_number}",
      actions: [
        {
          action: :create,
          file_path: "spec/test_seed_feature_#{mr_number}_spec.rb",
          content: <<~RUBY
            # frozen_string_literal: true

            require 'spec_helper'

            RSpec.describe TestSeedFeature#{mr_number} do
              describe '#greet' do
                it 'returns a greeting from Test Seed' do
                  feature = TestSeedFeature#{mr_number}.new('World')
                  expect(feature.greet).to eq('Hello, World! This is test seed feature #{mr_number}.')
                end
              end
            end
          RUBY
        }
      ],
      force: true
    )

    puts "Created feature branch #{branch_name} with #{NUM_COMMITS_PER_MR} commits"
  rescue Gitlab::Git::CommandError => e
    puts "Failed to create feature branch #{branch_name}, error: #{e.message}"
    exit(1)
  end
end
