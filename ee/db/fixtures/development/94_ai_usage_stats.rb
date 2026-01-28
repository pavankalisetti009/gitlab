# frozen_string_literal: true

require './spec/support/sidekiq_middleware'
require 'active_support/testing/time_helpers'

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
  extend ActiveSupport::Testing::TimeHelpers

  DEFAULT_EVENT_COUNT_SAMPLE = 15
  TIME_PERIOD_DAYS = 90

  attr_reader :project

  def self.sync_to_click_house
    ClickHouse::DumpAllWriteBuffersCronWorker::TABLES.each do |table_name|
      ClickHouse::DumpWriteBufferWorker.new.perform(table_name)
    end

    Gitlab::ExclusiveLease.skipping_transaction_check do
      ClickHouse::UserAddonAssignmentVersionsSyncWorker.new.perform
      # Re-sync data with ClickHouse
      ClickHouse::SyncCursor.update_cursor_for('events', 0)
      ClickHouse::EventsSyncWorker.new.perform
    end
  end

  def self.sync_to_postgres
    ::UsageEvents::DumpWriteBufferCronWorker.new.perform
    ::Analytics::AiAnalytics::EventsCountAggregationWorker.new.perform
    ::Analytics::DumpAiUserMetricsWriteBufferCronWorker.new.perform
  end

  def self.create_add_on_assignments(project)
    return if project.users.empty?

    namespace = project.project_namespace
    organization = namespace.organization

    # Find or create a Duo Pro add-on purchase for the namespace
    add_on = GitlabSubscriptions::AddOn.find_by(name: 'duo_enterprise') ||
      GitlabSubscriptions::AddOn.find_by(name: 'duo_pro')
    return unless add_on

    travel_to(TIME_PERIOD_DAYS.days.ago) do
      add_on_purchase = GitlabSubscriptions::AddOnPurchase.find_or_create_by!(
        namespace: namespace.root_ancestor,
        subscription_add_on_id: add_on.id
      ) do |purchase|
        purchase.organization = organization
        purchase.quantity = project.users.count
        purchase.started_at = Date.current
        purchase.expires_on = 1.year.from_now.to_date
        purchase.purchase_xid = "seed-#{SecureRandom.uuid}"
      end

      # Create user add-on assignments for all project users
      assigned_user_ids = add_on_purchase.assigned_users.pluck(:id)
      users_to_assign = project.users.where.not(id: assigned_user_ids)

      users_to_assign.each do |user|
        GitlabSubscriptions::UserAddOnAssignment.find_or_create_by!(
          add_on_purchase: add_on_purchase,
          user: user
        )
      end
    end

    puts "Created add-on assignments for #{project.users.count} users in '#{namespace.full_path}'"
  end

  def initialize(project)
    @project = project
  end

  def seed!
    if project.users.empty?
      puts "WARNING: Project '#{project.full_path}' has no users. Skipping AI usage event seeding."
      return
    end

    # Dynamically create events for all registered features
    Gitlab::Tracking::AiTracking.registered_features.each do |feature_name|
      create_events_for_feature(feature_name)
    end
  end

  private

  def save_event(**attributes)
    Ai::UsageEvent.new(attributes).tap(&:store_to_pg).tap(&:store_to_clickhouse)
  end

  def create_events_for_feature(feature_name)
    events = Gitlab::Tracking::AiTracking.registered_events(feature_name).keys

    if project.users.empty?
      puts "WARNING: Project '#{project.full_path}' has no users. Skipping AI usage event seeding."
      return
    end

    project.users.sample(5).each do |user|
      events.each do |event_name|
        rand(1..DEFAULT_EVENT_COUNT_SAMPLE).times do
          extras = generate_extras_for_event(event_name)
          timestamp = rand(TIME_PERIOD_DAYS).days.ago
          save_event(
            user: user,
            event: event_name,
            timestamp: timestamp,
            namespace: project.project_namespace,
            extras: extras
          )
          Ai::UserMetrics.refresh_last_activity_on(user, last_duo_activity_on: timestamp)
        end
      end
    end
  end

  def generate_extras_for_event(event_name)
    case event_name.to_s
    when /code_suggestion/
      generate_code_suggestion_extras
    when 'troubleshoot_job'
      generate_troubleshoot_job_extras
    when /agent_platform/
      generate_agent_platform_extras
    when /mcp/
      generate_mcp_extras
    else
      {}
    end
  end

  def generate_code_suggestion_extras
    {
      unique_tracking_id: SecureRandom.uuid,
      suggestion_size: rand(1..500),
      language: %w[ruby javascript python go java typescript].sample,
      branch_name: %w[main master develop feature/ai-improvements].sample,
      ide_name: %w[VSCode Vim Idea Neovim].sample,
      ide_vendor: %w[Microsoft JetBrains Neovim].sample,
      ide_version: "#{rand(1..10)}.#{rand(0..9)}.#{rand(0..9)}",
      extension_name: 'gitlab-editor-extension',
      extension_version: "#{rand(1..5)}.#{rand(0..9)}.#{rand(0..9)}",
      language_server_version: "#{rand(1..5)}.#{rand(0..9)}.#{rand(0..9)}",
      model_name: %w[claude-3-5-sonnet anthropic.claude-3-5-sonnet].sample,
      model_engine: %w[anthropic vertex-ai].sample
    }
  end

  def generate_troubleshoot_job_extras
    if project.builds.count == 0
      puts "WARNING: Project '#{project.full_path}' has no builds. Skipping troubleshoot_job extras generation."

      return {}
    end

    job = project.builds.sample
    {
      job_id: job.id,
      project_id: job.project_id,
      pipeline_id: job.pipeline&.id,
      merge_request_id: job.pipeline&.merge_request_id
    }
  end

  def generate_agent_platform_extras
    {
      project_id: project.id,
      session_id: rand(1..10000000),
      flow_type: %w[duo_chat code_review troubleshoot].sample,
      environment: %w[production development staging].sample
    }
  end

  def generate_mcp_extras
    has_tool_call_success = [true, false].sample.tap do |success|
      break { failure_reason: nil, error_status: nil } if success

      { failure_reason: %w[timeout permission_denied not_found].sample,
        error_status: [404, 500, 403].sample }
    end

    {
      session_id: rand(1..10000000),
      tool_name: %w[get_file search_code list_files execute_command].sample,
      has_tool_call_success: has_tool_call_success
    }
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

    "

    Gitlab::Utils.to_boolean(ENV["SEED_AI_USAGE_STATS"]) ? raise("ClickHouse is not configured") : break
  end

  unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?
    puts "
    WARNING:
    To use this seed file with ClickHouse, you need to make sure that ClickHouse for analytics is enabled with your GDK.

    In a Rails console session, enable ClickHouse for analytics and the feature flags:

    Gitlab::CurrentSettings.current_application_settings.update(use_clickhouse_for_analytics: true)
    "
  end

  project = Project.includes(:builds, :users).find_by(id: ENV['PROJECT_ID'])
  project ||= Project.first

  Sidekiq::Testing.inline! do
    # Create add-on purchase and assignments for the project's namespace
    Gitlab::Seeder::AiUsageStats.create_add_on_assignments(project)

    Gitlab::Seeder::AiUsageStats.new(project).seed!

    Gitlab::Seeder::AiUsageStats.sync_to_postgres
    Gitlab::Seeder::AiUsageStats.sync_to_click_house
  end

  puts "Successfully seeded '#{project.full_path}' for Ai Analytics!"
  puts "URL: #{Rails.application.routes.url_helpers.project_url(project)}"
end
# rubocop:enable Rails/Output
