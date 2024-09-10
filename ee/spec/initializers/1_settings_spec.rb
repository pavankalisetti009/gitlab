# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '1_settings', feature_category: :shared do
  it 'settings do not change after reload' do
    original_settings = Settings.to_h

    load_settings

    new_settings = Settings.to_h

    # Gitlab::Pages::Settings is a SimpleDelegator, so each time the settings
    # are reloaded a new SimpleDelegator wraps the original object. Convert
    # the settings to a Hash to ensure the comparison works.
    [new_settings, original_settings].each do |settings|
      settings['pages'] = settings['pages'].to_h
    end
    expect(new_settings).to eq(original_settings)
  end

  context 'cron jobs' do
    subject(:cron_jobs) { Settings.cron_jobs }

    context 'sync_seat_link_worker cron job' do
      # explicit use of UTC for self-managed instances to ensure job runs after a Customers Portal job
      it 'schedules the job at the correct time' do
        expect(cron_jobs.dig('sync_seat_link_worker', 'cron')).to match(/[1-5]{0,1}[0-9]{1,2} [34] \* \* \* UTC/)
      end
    end

    context 'sync_service_token_worker cron job' do
      # explicit use of UTC for self-managed instances to ensure job runs after a SyncSeatLink job
      it 'schedules the job at the correct time' do
        expect(cron_jobs.dig('sync_service_token_worker', 'cron')).to match(/[1-5]{0,1}[0-9]{1,2} [56] \* \* \* UTC/)
      end
    end

    context 'gitlab.com', :saas do
      let(:dot_com_cron_jobs) do
        %w[
          disable_legacy_open_source_license_for_inactive_projects
          notify_seats_exceeded_batch_worker
          gitlab_subscriptions_schedule_refresh_seats_worker
        ]
      end

      it 'assigns .com only settings' do
        load_settings

        expect(cron_jobs.keys).to include(*dot_com_cron_jobs)
      end
    end
  end

  describe 'cloud_connector' do
    subject(:cloud_connector_base_url) { Settings.cloud_connector.base_url }

    context 'when const CLOUD_CONNECTOR_BASE_URL is set' do
      before do
        stub_env("CLOUD_CONNECTOR_BASE_URL", 'https://www.cloud.example.com')
        load_settings
      end

      it { is_expected.to eq('https://www.cloud.example.com') }
    end

    context 'when const CLOUD_CONNECTOR_BASE_URL is not set' do
      before do
        load_settings
      end

      it { is_expected.to eq('https://cloud.gitlab.com') }
    end
  end

  describe 'duo_workflow' do
    before do
      Settings.duo_workflow = config
    end

    let(:config) { {} }

    context 'when service_url is set' do
      let(:config) do
        {
          service_url: "duo-workflow-service.example.com:50052",
          secure: false
        }
      end

      it 'uses provided config' do
        load_settings

        expect(Settings.duo_workflow.service_url).to eq('duo-workflow-service.example.com:50052')
        expect(Settings.duo_workflow.secure).to eq(false)
      end
    end

    context 'when service_url is not set' do
      let(:config) do
        {
          service_url: ""
        }
      end

      it 'defaults to cloud connector config' do
        stub_env("CLOUD_CONNECTOR_BASE_URL", 'https://www.cloud.example.com')

        load_settings
        expect(Settings.duo_workflow.service_url).to eq('www.cloud.example.com:443')
        expect(Settings.duo_workflow.secure).to eq(true)
      end

      it 'infers secure and port from scheme' do
        stub_env("CLOUD_CONNECTOR_BASE_URL", 'http://www.cloud.example.com')

        load_settings

        expect(Settings.duo_workflow.service_url).to eq('www.cloud.example.com:80')
        expect(Settings.duo_workflow.secure).to eq(false)
      end
    end

    it 'reads executor details from DUO_WORKFLOW_EXECUTOR_VERSION file' do
      version = Rails.root.join('DUO_WORKFLOW_EXECUTOR_VERSION').read.chomp

      load_settings

      expect(Settings.duo_workflow.executor_binary_url).to eq("https://gitlab.com/api/v4/projects/58711783/packages/generic/duo-workflow-executor/#{version}/duo-workflow-executor.tar.gz")
      expect(Settings.duo_workflow.executor_version).to eq(version)
    end
  end

  def load_settings
    # Avoid wrapping Gitlab::Pages::Settings again
    Settings.pages = Settings.pages.__getobj__

    load Rails.root.join('config/initializers/1_settings.rb')
  end
end
