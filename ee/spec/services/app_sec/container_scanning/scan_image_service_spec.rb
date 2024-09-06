# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::ContainerScanning::ScanImageService, feature_category: :software_composition_analysis do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, developers: user) }

  let(:user_id) { user.id }
  let(:project_id) { project.id }
  let(:image) { "registry.gitlab.com/gitlab-org/security-products/dast/webgoat-8.0@test:latest" }

  before do
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(false)
  end

  shared_examples 'creates a throttled log entry' do
    it do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        a_hash_including(
          class: described_class.name,
          project_id: project_id,
          user_id: user_id,
          image: image,
          scan_type: :container_scanning,
          pipeline_source: described_class::SOURCE,
          limit_type: :container_scanning_for_registry_scans,
          message: 'Daily rate limit container_scanning_for_registry_scans reached'
        )
      )

      execute
    end
  end

  shared_examples 'does not creates a throttled log entry' do
    it do
      expect(Gitlab::AppJsonLogger).not_to receive(:info)

      execute
    end
  end

  describe '#pipeline_config' do
    subject(:pipeline_config) do
      described_class.new(
        image: image,
        project_id: project_id,
        user_id: user_id
      ).pipeline_config
    end

    it 'generates a valid yaml ci config' do
      lint = Gitlab::Ci::Lint.new(project: project, current_user: user)
      result = lint.validate(pipeline_config)

      expect(result).to be_valid
    end
  end

  describe '#execute' do
    subject(:execute) do
      described_class.new(
        image: image,
        project_id: project_id,
        user_id: user_id
      ).execute
    end

    context 'when a project is not present' do
      let(:project_id) { nil }

      it { is_expected.to be_nil }

      it_behaves_like 'does not creates a throttled log entry'
    end

    context 'when a user is not present' do
      let(:user_id) { nil }

      it { is_expected.to be_nil }

      it_behaves_like 'does not creates a throttled log entry'
    end

    context 'when a valid project and user is present' do
      let(:pipeline) { execute.payload }
      let(:build) { pipeline.builds.find_by(name: :container_scanning) }
      let(:metadata) { build.metadata }

      it 'creates a pipeline' do
        expect { execute }.to change { Ci::Pipeline.count }.by(1)
      end

      it 'does not create a throttled log entry' do
        # We expect some logs from Gitlab::Ci::Pipeline::CommandLogger,
        # but no logs from create_throttled_log_entry
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including("class" => "Gitlab::Ci::Pipeline::CommandLogger")
        )

        execute
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'container_scanning_for_registry_pipeline' }
        let(:additional_properties) do
          {
            property: 'success'
          }
        end
      end

      it 'sets correct artifacts configuration' do
        expect(metadata[:config_options][:artifacts]).to eq({
          paths: ["**/gl-sbom-*.cdx.json"],
          access: "developer",
          reports: {
            cyclonedx: ["**/gl-sbom-*.cdx.json"],
            container_scanning: []
          }
        })
      end

      it 'sets correct environment variables' do
        expect(metadata[:config_variables]).to include(
          { key: "GIT_STRATEGY", value: "none" },
          { key: "REGISTRY_TRIGGERED", value: "true" },
          { key: "CS_IMAGE", value: image }
        )
      end
    end

    context 'when the project has exceeded the daily scan limit' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it { is_expected.to be_nil }

      it_behaves_like 'creates a throttled log entry'
    end
  end
end
