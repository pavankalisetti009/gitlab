# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::HealthCheck::NodeStatusService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }
  let(:online_nodes) { instance_double(ActiveRecord::Relation) }
  let(:offline_nodes) { instance_double(ActiveRecord::Relation) }

  before do
    allow(logger).to receive(:info)
  end

  describe '#execute' do
    context 'when no nodes are configured' do
      before do
        allow(Search::Zoekt::Node).to receive_messages(count: 0, online: online_nodes)
        allow(online_nodes).to receive_messages(count: 0, empty?: true)
      end

      it 'returns unhealthy status with configuration error' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include('Configure and deploy Zoekt nodes to enable exact code search')
        expect(result[:warnings]).to be_empty
      end

      it 'logs no nodes configured error' do
        expect(logger).to receive(:info).with(include('✗ No nodes configured'))

        service.execute
      end
    end

    context 'when all nodes are offline' do
      before do
        allow(Search::Zoekt::Node).to receive_messages(count: 5, online: online_nodes)
        allow(online_nodes).to receive_messages(count: 0, empty?: true)
      end

      it 'returns unhealthy status with connectivity error' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include('Check Zoekt node connectivity and restart offline services')
        expect(result[:warnings]).to be_empty
      end

      it 'logs all nodes offline error' do
        expect(logger).to receive(:info).with(include('✗ 5 of 5 nodes offline'))

        service.execute
      end
    end

    context 'when some nodes are offline' do
      before do
        allow(Search::Zoekt::Node).to receive_messages(count: 5, online: online_nodes, offline: offline_nodes)
        allow(online_nodes).to receive_messages(count: 3, empty?: false, to_a: [], select: [], sum: 0.15)
        allow(offline_nodes).to receive_messages(empty?: false, minimum: 2.days.ago)
      end

      it 'returns degraded status with warning' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to include('Investigate 2 offline nodes and restore connectivity')
      end

      it 'logs partial online status' do
        expect(logger).to receive(:info).with(include('⚠ 3 of 5 nodes online'))
        expect(logger).to receive(:info).with(include('⚠ WARNING: Nodes offline'))

        service.execute
      end
    end

    context 'when some nodes are offline with unknown last seen time' do
      before do
        allow(Search::Zoekt::Node).to receive_messages(count: 3, online: online_nodes, offline: offline_nodes)
        allow(online_nodes).to receive_messages(count: 2, empty?: false, to_a: [], select: [], sum: 0.1)
        allow(offline_nodes).to receive_messages(empty?: false, minimum: nil)
      end

      it 'logs offline nodes with unknown last seen time' do
        expect(logger).to receive(:info).with(include('⚠ WARNING: Offline nodes with unknown last seen time'))

        service.execute
      end
    end

    context 'when all nodes are online' do
      let(:node1) { instance_double(Search::Zoekt::Node, storage_percent_used: 0.5) }
      let(:node2) { instance_double(Search::Zoekt::Node, storage_percent_used: 0.6) }

      before do
        allow(Search::Zoekt::Node).to receive_messages(count: 2, online: online_nodes, offline: offline_nodes)
        allow(online_nodes).to receive_messages(count: 2, empty?: false, to_a: [node1, node2], sum: 1.1, select: [])
        allow(offline_nodes).to receive(:empty?).and_return(true)
        allow(node1).to receive_messages(
          watermark_exceeded_critical?: false,
          watermark_exceeded_high?: false,
          storage_percent_used: 0.5
        )
        allow(node2).to receive_messages(
          watermark_exceeded_critical?: false,
          watermark_exceeded_high?: false,
          storage_percent_used: 0.6
        )
      end

      it 'returns healthy status when storage is healthy' do
        result = service.execute

        expect(result[:status]).to eq(:healthy)
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to be_empty
      end

      it 'logs all nodes online and healthy storage' do
        expect(logger).to receive(:info).with(include('✓ 2 of 2 nodes online'))
        expect(logger).to receive(:info).with(include('✓ Storage usage healthy (avg: 55.0%)'))

        service.execute
      end
    end

    context 'when nodes have high storage usage' do
      let(:high_usage_node1) { instance_double(Search::Zoekt::Node) }
      let(:high_usage_node2) { instance_double(Search::Zoekt::Node) }

      before do
        allow(Search::Zoekt::Node).to receive_messages(count: 2, online: online_nodes, offline: offline_nodes)
        allow(online_nodes).to receive_messages(count: 2, empty?: false, select: [high_usage_node1, high_usage_node2])
        allow(offline_nodes).to receive(:empty?).and_return(true)
      end

      context 'with critical storage usage' do
        before do
          allow(online_nodes).to receive(:select).and_return([high_usage_node1], [])
        end

        it 'returns unhealthy status' do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include('Add nodes or clean up storage on 1 nodes with critical usage')
        end

        it 'logs critical storage usage' do
          expect(logger).to receive(:info).with(include('✗ Critical storage usage on 1 nodes'))

          service.execute
        end
      end

      context 'with high storage usage' do
        before do
          allow(online_nodes).to receive(:select).and_return([], [high_usage_node1, high_usage_node2])
        end

        it 'returns degraded status' do
          result = service.execute

          expect(result[:status]).to eq(:degraded)
          expect(result[:warnings]).to include(
            'Monitor and consider adding nodes or expanding storage on 2 nodes with high usage'
          )
        end

        it 'logs high storage usage' do
          expect(logger).to receive(:info).with(include('⚠ High storage usage on 2 nodes'))

          service.execute
        end
      end
    end
  end

  describe '.execute' do
    it 'creates instance and calls execute' do
      allow(Search::Zoekt::Node).to receive_messages(count: 1, online: online_nodes)
      allow(online_nodes).to receive_messages(count: 1, empty?: false, sum: 0.5, to_a: [], select: [])

      expect(described_class).to receive(:new).with(logger: logger).and_call_original

      described_class.execute(logger: logger)
    end
  end
end
