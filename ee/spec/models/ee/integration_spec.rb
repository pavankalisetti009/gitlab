# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integration, feature_category: :integrations do
  describe '.integration_names' do
    subject { described_class.integration_names }

    it { is_expected.not_to include('google_cloud_platform_workload_identity_federation') }

    context 'when google workload identity federation integration feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      it { is_expected.to include('google_cloud_platform_workload_identity_federation') }
    end

    describe 'git_guardian_integration feature flag' do
      context 'when feature flag is enabled' do
        it 'includes git_guardian in Integration.project_specific_integration_names' do
          expect(described_class.integration_names)
            .to include('git_guardian')
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(git_guardian_integration: false)
        end

        it 'does not include git_guardian Integration.project_specific_integration_names' do
          expect(described_class.integration_names)
           .not_to include('git_guardian')
        end
      end
    end
  end

  describe '.project_specific_integration_names' do
    subject { described_class.project_specific_integration_names }

    it { is_expected.not_to include('google_cloud_platform_artifact_registry') }

    context 'when google artifact registry feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      it { is_expected.to include(*described_class::EE_PROJECT_LEVEL_ONLY_INTEGRATION_NAMES) }
    end
  end

  describe '.vulnerability_hooks' do
    it 'includes integrations where vulnerability_events is true' do
      create(:integration, active: true, vulnerability_events: true)

      expect(described_class.vulnerability_hooks.count).to eq 1
    end

    it 'excludes integrations where vulnerability_events is false' do
      create(:integration, active: true, vulnerability_events: false)

      expect(described_class.vulnerability_hooks.count).to eq 0
    end
  end

  describe '.integration_name_to_type' do
    it 'handles a simple case' do
      expect(described_class.integration_name_to_type(:asana)).to eq 'Integrations::Asana'
    end

    it 'raises an error if the name is unknown' do
      expect { described_class.integration_name_to_type('foo') }
        .to raise_exception(described_class::UnknownType, /foo/)
    end

    it 'handles all available_integration_names' do
      types = described_class.available_integration_names.map { |name| described_class.integration_name_to_type(name) }

      expect(types).to all(start_with('Integrations::'))
    end

    context 'with a Google Cloud integration' do
      it 'handles the name' do
        expect(described_class.integration_name_to_type(:google_cloud_platform_artifact_registry))
          .to eq('Integrations::GoogleCloudPlatform::ArtifactRegistry')
      end
    end
  end
end
