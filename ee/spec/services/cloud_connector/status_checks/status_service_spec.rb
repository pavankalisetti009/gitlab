# frozen_string_literal: true

require 'spec_helper'
require_relative 'probes/test_probe'

RSpec.describe CloudConnector::StatusChecks::StatusService, feature_category: :cloud_connector do
  let(:succeeded_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: true) }
  let(:failed_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: false) }
  let(:user) { build(:user) }
  let(:expected_execution_context) { { user: user } }

  subject(:service) { described_class.new(user: user, probes: probes) }

  it 'has the expected default probes' do
    expect(described_class::DEFAULT_PROBES).to match_array([
      an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe).and(
        have_attributes(host: 'cloud.gitlab.com', port: 443)
      ),
      an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe).and(
        have_attributes(host: 'customers.staging.gitlab.com', port: 443)
      ),
      an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe),
      an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
    ])
  end

  describe '#execute' do
    context 'when no arguments are passed' do
      subject(:service) { described_class.new(user: user) }

      before do
        stub_const("#{described_class}::DEFAULT_PROBES", [succeeded_probe])
      end

      it 'executes all probes and returns successful status result' do
        expect(succeeded_probe).to receive(:execute)
          .with(expected_execution_context)
          .and_call_original

        service.execute
      end
    end

    context 'when all probes succeed' do
      let(:probes) { [succeeded_probe, succeeded_probe] }

      it 'executes all probes and returns successful status result' do
        expect(succeeded_probe).to receive(:execute)
          .twice
          .with(expected_execution_context)
          .and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be true
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to be_nil
      end
    end

    context 'when any probe fails' do
      let(:probes) { [succeeded_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(succeeded_probe).to receive(:execute)
          .with(expected_execution_context)
          .and_call_original
        expect(failed_probe).to receive(:execute)
          .with(expected_execution_context)
          .and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end

    context 'when all probes fail' do
      let(:probes) { [failed_probe, failed_probe] }

      it 'executes all probes and returns unsuccessful status result' do
        expect(failed_probe).to receive(:execute)
          .twice
          .with(expected_execution_context)
          .and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end
  end
end
