# frozen_string_literal: true

class DataSeeder
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

    puts "################### CREATING MERGE REQUEST WITH FACTORY ###################"
    create_merge_request_with_factory
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

  def create_merge_request_with_factory
    existing_mr = @project.merge_requests.find_by( # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
      target_branch: @project.default_branch || 'main'
    )

    if existing_mr
      puts 'Merge request already exists'
      return existing_mr
    end

    # Create feature branch with changes
    create_feature_branch_with_changes

    # Create merge request
    mr = create(:merge_request,
      title: 'Add test seed feature implementation',
      description: 'This MR adds a new feature for test seed with documentation and tests',
      source_project: @project,
      target_project: @project,
      source_branch: 'feature/test-seed-feature',
      target_branch: @project.default_branch || 'main',
      author: @user
    )
    puts 'Created merge request'
    mr
  end

  def create_feature_branch_with_changes
    if @project.repository.branch_exists?('feature/test-seed-feature')
      puts 'Feature branch already exists'
      return
    end

    # Create feature branch from default branch using system user
    @project.repository.raw_repository.commit_files(
      system_user,
      branch_name: 'feature/test-seed-feature',
      start_branch_name: default_branch,
      message: 'Add TestSeed Feature class',
      actions: [
        {
          action: :create,
          file_path: 'lib/test_seed_feature.rb',
          content: <<~RUBY
            # frozen_string_literal: true

            class TestSeedFeature
              def initialize(name)
                @name = name
              end

              def greet
                "Hello, \#{@name}! This is test seed feature."
              end
            end
          RUBY
        }
      ],
      force: true
    )

    # Add test file to feature branch using system user
    @project.repository.raw_repository.commit_files(
      system_user,
      branch_name: 'feature/test-seed-feature',
      message: 'Add tests for TestSeedFeature',
      actions: [
        {
          action: :create,
          file_path: 'spec/test_seed_feature_spec.rb',
          content: <<~RUBY
            # frozen_string_literal: true

            require 'spec_helper'

            RSpec.describe TestSeedFeature do
              describe '#greet' do
                it 'returns a greeting from Test Seed' do
                  feature = TestSeedFeature.new('World')
                  expect(feature.greet).to eq('Hello, World! This is Test Seed feature.')
                end
              end
            end
          RUBY
        }
      ],
      force: true
    )
    puts 'Created feature branch with changes'
  rescue Gitlab::Git::CommandError => e
    puts "Failed to create feature branch error: #{e.message}"
    puts "Cannot continue seeding without feature branch"
    exit(1)
  end
end
