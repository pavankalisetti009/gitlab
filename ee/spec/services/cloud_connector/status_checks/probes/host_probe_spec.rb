# frozen_string_literal: true

RSpec.describe CloudConnector::StatusChecks::Probes::HostProbe, feature_category: :cloud_connector do
  describe '#execute' do
    subject(:probe) { described_class.new(host, port) }

    let(:host) { 'example.com' }
    let(:port) { 443 }

    context 'when the host is reachable' do
      before do
        allow(TCPSocket).to receive(:new).and_return(instance_double(TCPSocket, close: nil))
      end

      it 'returns a success result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be true
        expect(result.message).to match("#{host} reachable")
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
        expect(result.message).to match("#{host} could not be reached. If you use firewalls or proxy servers")
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
        expect(result.message).to match("#{host} could not be reached. If you use firewalls or proxy servers")
      end
    end
  end
end
