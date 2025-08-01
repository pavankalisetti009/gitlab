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
    return existing_user if existing_user

    create(:user,
      name: 'Test Seed Developer',
      username: 'test_seed_dev',
      email: "test_seed_dev_#{SecureRandom.hex(8)}@example.com"
    )
  end

  def create_group_with_factory
    group_path = "test-seed-group-#{SecureRandom.hex(4)}"

    existing_group = Group.find_by(path: group_path) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
    return existing_group if existing_group

    # Build the group without triggering callbacks, then save
    group = build(:group,
      name: 'Test Seed Group',
      path: group_path,
      description: 'A group for Test Seed testing',
      visibility_level: Gitlab::VisibilityLevel::PRIVATE
    )

    # Save the group first
    group.save!

    # Manually create CI namespace mirror if it doesn't exist
    Ci::NamespaceMirror.create!(namespace_id: group.id) unless Ci::NamespaceMirror.exists?(namespace_id: group.id) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn

    group.add_owner(@user)
    group
  end

  def create_project_with_factory
    project_path = "test-seed-project-#{SecureRandom.hex(4)}"

    existing_project = @group.projects.find_by(path: project_path) # rubocop:disable CodeReuse/ActiveRecord -- allowed in data seeder scripts:warn
    return existing_project if existing_project

    create(:project,
      name: 'Test Seed Project',
      path: project_path,
      namespace: @group,
      description: 'A test project for Test Seed with dummy repository',
      visibility_level: Gitlab::VisibilityLevel::PRIVATE,
      creator: @user
    )
  end

  def create_repository_for_project
    return if @project.repository_exists?

    @project.create_repository
    @project.repository.create_file(
      @user,
      'README.md',
      "# #{@project.name}\n\nWelcome to test seed Project!",
      message: 'Initial commit',
      branch_name: @project.default_branch || 'main'
    )
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
    return existing_mr if existing_mr

    create_feature_branch_with_changes

    create(:merge_request,
      title: 'Add test seed feature implementation',
      description: 'This MR adds a new feature for test seed with documentation and tests',
      source_project: @project,
      target_project: @project,
      source_branch: 'feature/test-seed-feature',
      target_branch: @project.default_branch || 'main',
      author: @user
    )
  end

  def create_feature_branch_with_changes
    return if @project.repository.branch_exists?('feature/test-seed-feature')

    default_branch = @project.default_branch || 'main'
    @project.repository.create_branch('feature/test-seed-feature', default_branch)

    files_to_create = [
      {
        path: 'lib/test_seed_feature.rb',
        content: <<~RUBY,
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
        message: 'Add TestSeed Feature class'
      },
      {
        path: 'spec/test_seed_feature_spec.rb',
        content: <<~RUBY,
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
        message: 'Add tests for TestSeedFeature'
      }
    ]

    files_to_create.each do |file_data|
      @project.repository.create_file(
        @user,
        file_data[:path],
        file_data[:content],
        message: file_data[:message],
        branch_name: 'feature/test-seed-feature'
      )
    end
  end
end
