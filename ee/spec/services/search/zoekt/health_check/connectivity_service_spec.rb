# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::HealthCheck::ConnectivityService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }
  let(:zoekt_client) { instance_double(Gitlab::Search::Zoekt::Client) }
  let(:online_nodes) { instance_double(ActiveRecord::Relation) }
  let_it_be(:project) { create(:project) }

  before do
    allow(logger).to receive(:info)
    allow(Gitlab::Search::Zoekt::Client).to receive(:instance).and_return(zoekt_client)
    allow(Project).to receive(:first).and_return(project)
  end

  describe '#execute' do
    context 'when JWT token generation fails' do
      before do
        allow(Search::Zoekt::JwtAuth).to receive(:authorization_header).and_return(nil)
        allow(Search::Zoekt::Node).to receive_messages(online: online_nodes)
        allow(online_nodes).to receive_messages(to_a: [])
      end

      it 'returns unhealthy status with JWT error' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include('Configure JWT secret for Zoekt authentication')
      end

      it 'logs JWT token generation failure' do
        expect(logger).to receive(:info).with(include('✗ JWT token generation failed'))

        service.execute
      end
    end

    context 'when JWT token generation raises exception' do
      before do
        allow(Search::Zoekt::JwtAuth).to receive(:authorization_header).and_raise(StandardError, 'JWT error')
        allow(Search::Zoekt::Node).to receive_messages(online: online_nodes)
        allow(online_nodes).to receive_messages(to_a: [])
      end

      it 'returns unhealthy status with JWT configuration error' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include('Fix JWT configuration - JWT error')
      end

      it 'logs JWT token generation error' do
        expect(logger).to receive(:info).with(include('✗ JWT token generation error'))

        service.execute
      end
    end

    context 'when JWT token generation succeeds' do
      let(:node1) { instance_double(Search::Zoekt::Node, id: 1, metadata: { 'name' => 'node1' }) }
      let(:node2) { instance_double(Search::Zoekt::Node, id: 2, metadata: { 'name' => 'node2' }) }

      before do
        allow(Search::Zoekt::JwtAuth).to receive(:authorization_header).and_return('valid-token')
        allow(Search::Zoekt::Node).to receive_messages(online: online_nodes)
      end

      context 'when no online nodes exist' do
        before do
          allow(online_nodes).to receive_messages(to_a: [])
        end

        it 'returns healthy status with successful JWT' do
          result = service.execute

          expect(result[:status]).to eq(:healthy)
          expect(result[:errors]).to be_empty
        end

        it 'logs successful JWT generation' do
          expect(logger).to receive(:info).with(include('✓ JWT token generation successful'))

          service.execute
        end
      end

      context 'when all nodes are reachable' do
        before do
          allow(online_nodes).to receive_messages(to_a: [node1, node2])
          allow(zoekt_client).to receive(:search).and_return(true)
        end

        it 'returns healthy status' do
          result = service.execute

          expect(result[:status]).to eq(:healthy)
          expect(result[:errors]).to be_empty
          expect(result[:warnings]).to be_empty
        end

        it 'logs successful connectivity' do
          expect(logger).to receive(:info).with(include('✓ JWT token generation successful'))
          expect(logger).to receive(:info).with(include('✓ Node 1 (node1)'))
          expect(logger).to receive(:info).with(include('✓ Node 2 (node2)'))
          expect(logger).to receive(:info).with(include('✓ All 2 online nodes reachable'))

          service.execute
        end

        it 'calls zoekt client with correct parameters' do
          expect(zoekt_client).to receive(:search).with(
            described_class::HEALTH_CHECK_QUERY,
            num: 1,
            project_ids: [project.id],
            node_id: 1,
            search_mode: :exact,
            source: 'health_check'
          )
          expect(zoekt_client).to receive(:search).with(
            described_class::HEALTH_CHECK_QUERY,
            num: 1,
            project_ids: [project.id],
            node_id: 2,
            search_mode: :exact,
            source: 'health_check'
          )

          service.execute
        end
      end

      context 'when some nodes have connection errors' do
        before do
          allow(online_nodes).to receive_messages(to_a: [node1, node2])
          allow(zoekt_client).to receive(:search).with(
            anything, hash_including(node_id: 1)
          ).and_return(true)
          allow(zoekt_client).to receive(:search).with(
            anything, hash_including(node_id: 2)
          ).and_raise(Search::Zoekt::Errors::ClientConnectionError)
        end

        it 'returns degraded status with connectivity warnings' do
          result = service.execute

          expect(result[:status]).to eq(:degraded)
          expect(result[:warnings]).to include('Check network connectivity and node status for node 2')
        end

        it 'logs partial connectivity' do
          expect(logger).to receive(:info).with(include('✓ Node 1 (node1)'))
          expect(logger).to receive(:info).with(include('⚠ Node 2 (node2) - connection failed'))
          expect(logger).to receive(:info).with(include('⚠ 1/2 nodes reachable'))

          service.execute
        end
      end

      context 'when all nodes are unreachable' do
        before do
          allow(online_nodes).to receive_messages(to_a: [node1, node2])
          allow(zoekt_client).to receive(:search).and_raise(Search::Zoekt::Errors::ClientConnectionError)
        end

        it 'returns unhealthy status with connectivity error' do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include('Restore network connectivity to all Zoekt nodes')
        end

        it 'logs no connectivity' do
          expect(logger).to receive(:info).with(include('⚠ Node 1 (node1) - connection failed'))
          expect(logger).to receive(:info).with(include('⚠ Node 2 (node2) - connection failed'))
          expect(logger).to receive(:info).with(include('✗ No nodes reachable'))

          service.execute
        end
      end

      context 'when nodes have other errors' do
        before do
          allow(online_nodes).to receive_messages(to_a: [node1])
          allow(zoekt_client).to receive(:search).and_raise(ArgumentError, 'Invalid params')
        end

        it 'returns unhealthy status with connectivity error' do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include('Restore network connectivity to all Zoekt nodes')
        end

        it 'logs connection failure' do
          expect(logger).to receive(:info).with(include('✗ Node 1 (node1) - ArgumentError: Invalid params'))

          service.execute
        end
      end

      context 'when node connectivity raises unexpected exception' do
        before do
          allow(online_nodes).to receive_messages(to_a: [node1])
          allow(zoekt_client).to receive(:search).and_raise(StandardError, 'Unexpected error')
        end

        it 'returns unhealthy status with network error' do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include('Restore network connectivity to all Zoekt nodes')
        end

        it 'logs detailed error information' do
          expect(logger).to receive(:info).with(include('✗ Node 1 (node1) - StandardError: Unexpected error'))

          service.execute
        end
      end

      context 'when node has no name in metadata' do
        let(:unnamed_node) { instance_double(Search::Zoekt::Node, id: 3, metadata: {}) }

        before do
          allow(online_nodes).to receive_messages(to_a: [unnamed_node])
          allow(zoekt_client).to receive(:search).and_return(true)
        end

        it 'handles unnamed nodes correctly' do
          expect(logger).to receive(:info).with(include('✓ Node 3 (unnamed)'))

          service.execute
        end
      end

      context 'when no project exists' do
        before do
          allow(Project).to receive(:first).and_return(nil)
          allow(online_nodes).to receive_messages(to_a: [node1])
          allow(zoekt_client).to receive(:search).and_return(true)
        end

        it 'uses fallback project ID 1' do
          expect(zoekt_client).to receive(:search).with(
            described_class::HEALTH_CHECK_QUERY,
            num: 1,
            project_ids: [1],
            node_id: 1,
            search_mode: :exact,
            source: 'health_check'
          )

          service.execute
        end
      end
    end
  end

  describe '.execute' do
    it 'creates instance and calls execute' do
      allow(Search::Zoekt::JwtAuth).to receive(:authorization_header).and_return('jwt-token')
      allow(Search::Zoekt::Node).to receive_messages(online: online_nodes)
      allow(online_nodes).to receive_messages(to_a: [])

      expect(described_class).to receive(:new).with(logger: logger).and_call_original

      described_class.execute(logger: logger)
    end
  end
end
