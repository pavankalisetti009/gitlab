# frozen_string_literal: true

require 'spec_helper'
require_relative 'probes/test_probe'

RSpec.describe CloudConnector::StatusChecks::StatusService, feature_category: :cloud_connector do
  let(:succeeded_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: true) }
  let(:failed_probe) { CloudConnector::StatusChecks::Probes::TestProbe.new(success: false) }
  let(:user) { build(:user) }

  subject(:service) { described_class.new(user: user, probes: probes) }

  describe '#initialize' do
    context 'when no probes are passed' do
      subject(:service) { described_class.new(user: user) }

      it 'created default probes' do
        service_probes = service.probes

        expect(service_probes.count).to eq(6)
        expect(service_probes[0]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::LicenseProbe)
        expect(service_probes[1]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe)
        expect(service_probes[2]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::HostProbe)
        expect(service_probes[3]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::AccessProbe)
        expect(service_probes[4]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::TokenProbe)
        expect(service_probes[5]).to be_an_instance_of(CloudConnector::StatusChecks::Probes::EndToEndProbe)
      end
    end
  end

  describe '#execute' do
    context 'when all probes succeed' do
      let(:probes) { [succeeded_probe, succeeded_probe] }

      it 'executes all probes and returns successful status result' do
        expect(succeeded_probe).to receive(:execute).twice.and_call_original

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
        expect(succeeded_probe).to receive(:execute).and_call_original
        expect(failed_probe).to receive(:execute).and_call_original

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
        expect(failed_probe).to receive(:execute).twice.and_call_original

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be false
        expect(result[:probe_results].size).to eq(2)
        expect(result.message).to eq('Some probes failed')
      end
    end
  end
end
