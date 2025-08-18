# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::StatisticsUpdateService, feature_category: :vulnerability_management do
  describe '.update_for' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }
    let(:vulnerability) { instance_double(Vulnerability) }

    subject(:update_for) { described_class.update_for(vulnerability) }

    before do
      allow(described_class).to receive(:new).with(vulnerability).and_return(mock_service_object)
    end

    it 'instantiates an instance of service class and calls execute on it' do
      update_for

      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project) }

    let(:service) { described_class.new(vulnerability) }
    let(:stat_diff) { instance_double(Vulnerabilities::StatDiff) }
    let(:update_required) { true }
    let(:severity_changes) do
      {
        'critical' => 1,
        'high' => -1,
        'medium' => 0,
        'low' => 0,
        'unknown' => 0,
        'info' => 0
      }
    end

    subject(:execute) { service.execute }

    before do
      allow(vulnerability).to receive(:stat_diff).and_return(stat_diff)
      allow(stat_diff)
        .to receive_messages(update_required?: update_required, changes: { 'critical' => 1, 'high' => -1 })
    end

    context 'when vulnerability is nil' do
      let(:service) { described_class.new(nil) }

      it 'returns early without calling any services' do
        expect(Vulnerabilities::Statistics::UpdateService).not_to receive(:update_for)
        expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)
        expect(Security::InventoryFilters::VulnerabilityStatisticsUpdateService).not_to receive(:execute)

        execute
      end
    end

    context 'when vulnerability is present' do
      context 'when stat_diff update is required' do
        let(:update_required) { true }

        it 'calls Statistics::UpdateService with the vulnerability' do
          expect(Vulnerabilities::Statistics::UpdateService).to receive(:update_for).with(vulnerability)
          allow(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
          allow(Security::InventoryFilters::VulnerabilityStatisticsUpdateService).to receive(:execute)

          execute
        end

        it 'calls Vulnerabilities::NamespaceStatistics::UpdateService with the correct diffs' do
          allow(Vulnerabilities::Statistics::UpdateService).to receive(:update_for)
          allow(Security::InventoryFilters::VulnerabilityStatisticsUpdateService).to receive(:execute)

          expected_diffs = [{
            "namespace_id" => namespace.id,
            "traversal_ids" => "{#{namespace.traversal_ids.join(', ')}}",
            'critical' => 1,
            'high' => -1,
            'medium' => 0,
            'low' => 0,
            'unknown' => 0,
            'info' => 0
          }]

          expect(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute).with(expected_diffs)

          execute
        end

        it 'calls Security::InventoryFilters::VulnerabilityStatisticsUpdateService with the correct diffs' do
          allow(Vulnerabilities::Statistics::UpdateService).to receive(:update_for)
          allow(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)

          expected_diffs = {
            vulnerability.project => severity_changes
          }

          expect(Security::InventoryFilters::VulnerabilityStatisticsUpdateService)
            .to receive(:execute).with(expected_diffs)

          execute
        end
      end

      context 'when stat_diff update is not required' do
        let(:update_required) { false }

        it 'returns early without calling any services' do
          expect(Vulnerabilities::Statistics::UpdateService).not_to receive(:update_for)
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)
          expect(Security::InventoryFilters::VulnerabilityStatisticsUpdateService).not_to receive(:execute)

          execute
        end
      end

      context 'when stat_diff is nil' do
        let(:stat_diff) { nil }

        it 'returns early without calling any services' do
          expect(Vulnerabilities::Statistics::UpdateService).not_to receive(:update_for)
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)
          expect(Security::InventoryFilters::VulnerabilityStatisticsUpdateService).not_to receive(:execute)

          execute
        end
      end
    end
  end
end
