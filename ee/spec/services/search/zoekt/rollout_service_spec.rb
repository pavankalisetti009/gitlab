# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::RolloutService, feature_category: :global_search do
  let(:logger) { instance_double(Logger, info: nil) }
  let(:resource_pool) do
    instance_double(::Search::Zoekt::SelectionService::ResourcePool,
      enabled_namespaces: enabled_namespaces,
      nodes: nodes)
  end

  let(:plan) { instance_double(::Search::Zoekt::PlanningService::Plan, to_json: '{"plan": "data"}') }
  let(:default_options) do
    {
      num_replicas: 1,
      max_indices_per_replica: 5,
      dry_run: true,
      batch_size: 128,
      logger: logger
    }
  end

  let(:selection_service) do
    ::Search::Zoekt::SelectionService
  end

  let(:planning_service) do
    ::Search::Zoekt::PlanningService
  end

  let(:provisioning_service) do
    ::Search::Zoekt::ProvisioningService
  end

  let(:enabled_namespaces) { ['namespace1'] }
  let(:nodes) { ['node1'] }

  subject(:service) { described_class.new(**options) }

  describe '#execute' do
    subject(:result) { service.execute }

    let(:options) { {} }

    before do
      allow(selection_service).to receive(:execute)
        .with(max_batch_size: default_options[:batch_size])
        .and_return(resource_pool)
    end

    context 'when no enabled namespaces are found' do
      let(:enabled_namespaces) { [] }

      it 'returns a failed result with appropriate message' do
        expect(result.success?).to be false
        expect(result.message).to eq("No enabled namespaces found")
      end
    end

    context 'when no available nodes are found' do
      let(:nodes) { [] }

      it 'returns a failed result with appropriate message' do
        expect(result.success?).to be false
        expect(result.message).to eq("No available nodes found")
      end
    end

    context 'when dry_run is true' do
      let(:options) { { dry_run: true, logger: logger } }

      before do
        allow(planning_service).to receive(:plan)
          .with(
            enabled_namespaces: enabled_namespaces,
            nodes: nodes,
            num_replicas: default_options[:num_replicas],
            max_indices_per_replica: default_options[:max_indices_per_replica]
          )
          .and_return(plan)
      end

      it 'returns a successful result indicating a skipped execution' do
        expect(result.success?).to be true
        expect(result.message).to eq("Skipping execution of changes because of dry run")
      end
    end

    context 'when dry_run is false and provisioning returns errors' do
      let(:options) { { dry_run: false, logger: logger } }
      let(:changes) { { errors: 'some error occurred' } }

      before do
        allow(planning_service).to receive(:plan)
          .with(
            enabled_namespaces: enabled_namespaces,
            nodes: nodes,
            num_replicas: default_options[:num_replicas],
            max_indices_per_replica: default_options[:max_indices_per_replica]
          )
          .and_return(plan)

        allow(provisioning_service).to receive(:execute)
          .with(plan)
          .and_return(changes)
      end

      it 'returns a failed result with the provisioning error message' do
        expect(result.success?).to be false
        expect(result.message).to eq("Change had an error: some error occurred")
      end
    end

    context 'when dry_run is false and provisioning succeeds' do
      let(:options) { { dry_run: false, logger: logger } }
      let(:changes) { { errors: nil } }

      before do
        allow(planning_service).to receive(:plan)
          .with(
            enabled_namespaces: enabled_namespaces,
            nodes: nodes,
            num_replicas: default_options[:num_replicas],
            max_indices_per_replica: default_options[:max_indices_per_replica]
          )
          .and_return(plan)

        allow(provisioning_service).to receive(:execute)
          .with(plan)
          .and_return(changes)
      end

      it 'returns a successful result indicating completion' do
        expect(result.success?).to be true
        expect(result.message).to eq("Rollout execution completed successfully")
      end
    end
  end

  describe '.execute' do
    let(:options) { { dry_run: true, logger: logger } }

    it 'delegates to an instance of RolloutService' do
      instance = instance_double(described_class)
      expect(described_class).to receive(:new).with(**options).and_return(instance)
      expect(instance).to receive(:execute)
      described_class.execute(**options)
    end
  end
end
