# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::HostProbe, feature_category: :cloud_connector do
  describe '#execute' do
    subject(:probe) { described_class.new(uri) }

    let(:uri) { 'https://example.com' }

    context 'when the host is reachable' do
      before do
        allow(TCPSocket).to receive(:new).and_return(instance_double(TCPSocket, close: nil))
      end

      it 'returns a success result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be true
        expect(result.message).to match("example.com reachable")
      end
    end

    context 'when the host is unreachable' do
      before do
        allow(TCPSocket).to receive(:new).and_raise(Errno::EHOSTUNREACH)
      end

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match("example.com could not be reached. If you use firewalls or proxy servers")
      end
    end

    context 'when the network is unreachable' do
      before do
        allow(TCPSocket).to receive(:new).and_raise(Errno::ENETUNREACH)
      end

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match("example.com could not be reached. If you use firewalls or proxy servers")
      end
    end

    context 'when connection cannot be established for other reasons' do
      before do
        allow(TCPSocket).to receive(:new).and_raise(StandardError.new('the cause'))
      end

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match("example.com connection failed: the cause")
      end
    end
  end
end
