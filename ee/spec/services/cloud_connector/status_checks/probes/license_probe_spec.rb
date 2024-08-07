# frozen_string_literal: true

RSpec.describe CloudConnector::StatusChecks::Probes::LicenseProbe, feature_category: :cloud_connector do
  describe '#execute' do
    subject(:probe) { described_class.new }

    before do
      allow(License).to receive(:current).and_return(license)
    end

    context 'when no license is found' do
      let(:license) { nil }

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match('Contact GitLab customer support to obtain a license')
      end
    end

    context 'when a license is found but it is not an Online Cloud License' do
      let(:license) { instance_double(License, online_cloud_license?: false) }

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match('Contact GitLab customer support to upgrade your license')
      end
    end

    context 'when an Online Cloud License is found' do
      let(:license) { instance_double(License, online_cloud_license?: true) }

      it 'returns a success result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be true
        expect(result.message).to match('Subscription can be synchronized')
      end
    end
  end
end
