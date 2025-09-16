# frozen_string_literal: true

# Usage:
#
# Seeds all groups:
#
# FILTER=ai_usage_stats bundle exec rake db:seed_fu
#
# Invoking for a single project:
#
# PROJECT_ID=22 FILTER=ai_usage_stats bundle exec rake db:seed_fu

# rubocop:disable Rails/Output -- this is a seed script
class Gitlab::Seeder::AiUsageStats # rubocop:disable Style/ClassAndModuleChildren -- this is a seed script
  CODE_PUSH_SAMPLE = 10
  CS_EVENT_COUNT_SAMPLE = 5
  CHAT_EVENT_COUNT_SAMPLE = 2
  TROUBLESHOOT_EVENT_COUNT_SAMPLE = 2
  TIME_PERIOD_DAYS = 90

  attr_reader :project

  def self.sync_to_click_house
    ClickHouse::DumpAllWriteBuffersCronWorker::TABLES.each do |table_name|
      ClickHouse::DumpWriteBufferWorker.new.perform(table_name)
    end

    # Re-sync data with ClickHouse
    ClickHouse::SyncCursor.update_cursor_for('events', 0)
    Gitlab::ExclusiveLease.skipping_transaction_check do
      ClickHouse::EventsSyncWorker.new.perform
    end
  end

  def self.sync_to_postgres
    ::UsageEvents::DumpWriteBufferCronWorker.new.perform
  end

  def initialize(project)
    @project = project
  end

  def seed!
    create_code_suggestions_data
    create_chat_data
    create_troubleshoot_job_data
  end

  private

  def save_event(**attributes)
    Ai::UsageEvent.new(attributes).tap(&:store_to_pg).tap(&:store_to_clickhouse)
  end

  def create_code_suggestions_data
    project.users.count.times do
      user = project.users.sample

      CODE_PUSH_SAMPLE.times do
        Event.create!(
          project: project,
          author: user,
          action: :pushed,
          created_at: rand(TIME_PERIOD_DAYS).days.ago
        )
      end

      extras = {
        unique_tracking_id: 'FOO',
        branch_name: 'main',
        ide_vendor: 'IDEVendor',
        ide_version: '8.1.1',
        extension_name: 'gitlab-editor-extension',
        extension_version: '2.1.1',
        language_server_version: '3.2.2'
      }

      CS_EVENT_COUNT_SAMPLE.times do
        extras[:suggestion_size] = rand(100)
        extras[:language] = %w[ruby js go].sample
        extras[:ide_name] = %w[VSCode Vim Idea].sample

        save_event(
          user: user,
          event: 'code_suggestion_shown_in_ide',
          timestamp: rand(TIME_PERIOD_DAYS).days.ago,
          namespace: project.project_namespace,
          extras: extras)

        next unless rand(100) < 35 # 35% acceptance rate

        save_event(
          user: user,
          event: 'code_suggestion_accepted_in_ide',
          timestamp: rand(TIME_PERIOD_DAYS).days.ago + 2.seconds,
          namespace: project.project_namespace,
          extras: extras)
      end
    end
  end

  def create_chat_data
    project.users.count.times do
      user = project.users.sample

      CHAT_EVENT_COUNT_SAMPLE.times do
        save_event(user: user, event: 'request_duo_chat_response', timestamp: rand(TIME_PERIOD_DAYS).days.ago)
      end
    end
  end

  def create_troubleshoot_job_data
    return unless project.builds.count > 0

    builds = project.builds

    project.users.count.times do
      user = project.users.sample

      TROUBLESHOOT_EVENT_COUNT_SAMPLE.times do
        job = builds.sample
        save_event(
          user: user,
          event: 'troubleshoot_job',
          namespace: project.project_namespace,
          extras: {
            job_id: job.id,
            project_id: job.project_id,
            pipeline_id: job.pipeline&.id,
            merge_request_id: job.pipeline&.merge_request_id
          },
          timestamp: rand(TIME_PERIOD_DAYS).days.ago)
      end
    end
  end
end

Gitlab::Seeder.quiet do
  feature_available = ::Gitlab::ClickHouse.globally_enabled_for_analytics?

  unless feature_available
    puts "
    WARNING:
    To use this seed file, you need to make sure that ClickHouse is configured and enabled with your GDK.
    Please check `doc/development/database/clickhouse/clickhouse_within_gitlab.md` for setup instructions.
    Once you've configured the config/click_house.yml file, run the migrations:

    > bundle exec rake gitlab:clickhouse:migrate

    In a Rails console session, enable ClickHouse for analytics and the feature flags:

    Gitlab::CurrentSettings.current_application_settings.update(use_clickhouse_for_analytics: true)
    "
    break
  end

  projects = Project.all
  projects = projects.id_in(ENV['PROJECT_ID']) if ENV['PROJECT_ID']

  projects.find_each do |project|
    Gitlab::Seeder::AiUsageStats.new(project).seed!
  end

  Gitlab::Seeder::AiUsageStats.sync_to_postgres
  Gitlab::Seeder::AiUsageStats.sync_to_click_house
end
# rubocop:enable Rails/Output
