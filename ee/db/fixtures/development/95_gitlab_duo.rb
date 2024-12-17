# frozen_string_literal: true

# This class is responsible for seeding group/project resources for testing GitLab Duo features.
# See https://docs.gitlab.com/ee/development/ai_features/index.html#seed-project-and-group-resources-for-testing-and-evaluation
# for more information.
class Gitlab::Seeder::GitLabDuo # rubocop:disable Style/ClassAndModuleChildren -- this is a seed script
  GROUP_PATH = 'gitlab-duo'
  PROJECT_PATH = 'test'
  ID_BASE = 1_000_000

  def seed!
    user = User.find_by_username('root')

    puts "Seeding resources to #{GROUP_PATH} group..."
    group = FactoryBot.create(:group, :public, id: ID_BASE, name: 'GitLab Duo', path: GROUP_PATH)
    project = FactoryBot.create(:project, :public, :repository, id: ID_BASE, name: 'Test', path: PROJECT_PATH,
      creator: user, namespace: group)
    group.add_owner(user)
    project.add_owner(user)

    FactoryBot.create(:epic, id: ID_BASE, group: group, author: user)
    FactoryBot.create(:issue, id: ID_BASE, iid: 1, project: project, assignees: [user])
    FactoryBot.create(:merge_request_with_diffs, id: ID_BASE, iid: 1, source_project: project, author: user)
    FactoryBot.create(:ci_empty_pipeline, status: :success, project: project,
      partition_id: Ci::Pipeline.current_partition_value, user: user).tap do |pipeline|
      pipeline.update_column(:id, ID_BASE)

      FactoryBot.create(:ci_stage, :success, pipeline: pipeline, name: 'test').tap do |stage|
        stage.update_column(:id, ID_BASE)

        FactoryBot.create(:ci_build, :success, pipeline: pipeline, ci_stage: stage,
          stage_idx: 1, project: project, user: user).tap do |build|
          build.update_column(:id, ID_BASE)

          FactoryBot.create(:ci_job_artifact, :trace, job: build)
        end
      end
    end
  end

  def clean!
    user = User.find_by_username('root')

    project = Project.find_by_full_path("#{GROUP_PATH}/#{PROJECT_PATH}")
    group = Group.find_by_path(GROUP_PATH)

    if project
      puts "Destroying #{GROUP_PATH}/#{PROJECT_PATH} project..."
      Sidekiq::Worker.skipping_transaction_check do
        Projects::DestroyService.new(project, user).execute
        project.send(:_run_after_commit_queue)
        project.repository.expire_all_method_caches
      end
    end

    if group
      puts "Destroying #{GROUP_PATH} group..."
      Sidekiq::Worker.skipping_transaction_check do
        Groups::DestroyService.new(group, user).execute
      end
    end

    # Synchronously execute LooseForeignKeys::CleanupWorker
    # to delete the records associated with the static ID.
    Gitlab::ExclusiveLease.skipping_transaction_check do
      LooseForeignKeys::CleanupWorker.new.perform
    end
  end
end

FactoryBot::SyntaxRunner.class_eval do
  # FactoryBot doesn't allow yet to add a helper that can be used in factories
  # While the fixture_file_upload helper is reasonable to be used there:
  #
  # https://github.com/thoughtbot/factory_bot/issues/564#issuecomment-389491577
  def fixture_file_upload(*args, **kwargs)
    Rack::Test::UploadedFile.new(*args, **kwargs)
  end
end

Gitlab::Seeder.quiet do
  flag = ENV['SEED_GITLAB_DUO']

  unless flag
    puts "Skipped. Use the SEED_GITLAB_DUO=1 environment variable to enable."
    next
  end

  Gitlab::Seeder::GitLabDuo.new.clean!
  Gitlab::Seeder::GitLabDuo.new.seed!
end
