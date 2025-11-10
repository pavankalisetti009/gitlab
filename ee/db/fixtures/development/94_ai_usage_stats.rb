# frozen_string_literal: true

require './spec/support/sidekiq_middleware'

# Usage:
#
# Seeds first project:
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
  CODE_REVIEW_EVENT_COUNT_SAMPLE = 10
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
    Sidekiq::Testing.inline! do
      ::UsageEvents::DumpWriteBufferCronWorker.new.perform
      ::Analytics::AiAnalytics::EventsCountAggregationWorker.new.perform
    end
  end

  def initialize(project)
    @project = project
  end

  def seed!
    create_code_suggestions_data
    create_chat_data
    create_troubleshoot_job_data
    create_code_review_data
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

  def create_code_review_data
    code_review_events = Gitlab::Tracking::AiTracking.registered_events(:code_review).keys

    project.users.count.times do
      user = project.users.sample

      CODE_REVIEW_EVENT_COUNT_SAMPLE.times do
        save_event(
          user: user,
          event: code_review_events.sample,
          timestamp: rand(TIME_PERIOD_DAYS).days.ago,
          namespace: project.project_namespace
        )
      end
    end
  end
end

Gitlab::Seeder.quiet do
  # Environment variable used on CI to to allow requests to ClickHouse docker container
  WebMock.allow_net_connect! if Rails.env.test? && ENV['DISABLE_WEBMOCK']

  unless ::Gitlab::ClickHouse.configured?
    puts "
    WARNING:
    To use this seed file, you need to make sure that ClickHouse is configured and enabled with your GDK.
    Please check `doc/development/database/clickhouse/clickhouse_within_gitlab.md` for setup instructions.
    Once you've configured the config/click_house.yml file, run the migrations:

    > bundle exec rake gitlab:clickhouse:migrate

    In a Rails console session, enable ClickHouse for analytics and the feature flags:

    Gitlab::CurrentSettings.current_application_settings.update(use_clickhouse_for_analytics: true)
    "

    Gitlab::Utils.to_boolean(ENV["SEED_AI_USAGE_STATS"]) ? raise("ClickHouse is not configured") : break
  end

  project = Project.find_by(id: ENV['PROJECT_ID'])
  project ||= Project.first

  Gitlab::Seeder::AiUsageStats.new(project).seed!

  Gitlab::Seeder::AiUsageStats.sync_to_postgres
  Gitlab::Seeder::AiUsageStats.sync_to_click_house

  puts "Successfully seeded '#{project.full_path}' for Ai Analytics!"
  puts "URL: #{Rails.application.routes.url_helpers.project_url(project)}"
end
# rubocop:enable Rails/Output
