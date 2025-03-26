# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::AdjustmentService, feature_category: :vulnerability_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:group_project) { create(:project, namespace: group) }
  let(:sub_group_project) { create(:project, namespace: sub_group) }

  def group_statistics(group)
    statistic = Vulnerabilities::NamespaceStatistic
                  .find_by(namespace_id: group.id)
    return unless statistic

    statistic.reload.as_json(except: [:id, :created_at, :updated_at])
  end

  describe '.execute' do
    let(:namespace_ids) { [1, 2, 3] }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_for_namespace_ids) { described_class.execute(namespace_ids) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object for given namespace ids and calls `execute` on them', :aggregate_failures do
      execute_for_namespace_ids

      expect(described_class).to have_received(:new).with([1, 2, 3])
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:namespace_ids) { [sub_group.id, root_group.id, group.id] }

    subject(:adjust_statistics) { described_class.new(namespace_ids).execute }

    context 'when more than 1000 namespaces ids are provided' do
      let(:namespace_ids) { (1..1001).to_a }

      it 'raises error' do
        expect { adjust_statistics }.to raise_error do |error|
          expect(error.class).to eql(described_class::TooManyNamespacesError)
          expect(error.message).to eql("Cannot adjust namespace statistics for more than 1000 namespaces")
        end
      end
    end

    context 'with empty namespace_ids array' do
      let(:namespace_ids) { [] }

      it 'does not create new namespace_statistics records' do
        expect { adjust_statistics }.not_to change { Vulnerabilities::NamespaceStatistic.count }
      end
    end

    context 'when a namespace has no projects' do
      let(:empty_group) { create(:group) }
      let(:namespace_ids) { [empty_group.id] }

      it 'does not create new namespace_statistics records' do
        expect { adjust_statistics }.not_to change { Vulnerabilities::NamespaceStatistic.count }
      end
    end

    context 'when there are no vulnerability_statistic record for the groups projects' do
      it 'does not create a new record in database' do
        expect { adjust_statistics }.not_to change { Vulnerabilities::NamespaceStatistic.count }
      end
    end

    context 'when there are vulnerability_statistic records for the groups projects' do
      let!(:group_project_statistics) do
        create(:vulnerability_statistic, project: group_project, total: 2, critical: 1, high: 1)
      end

      let!(:sub_group_project_statistics) do
        create(:vulnerability_statistic, project: sub_group_project, total: 2, critical: 1, high: 1)
      end

      let(:expected_single_project_statistics) do
        {
          'total' => 2,
          'critical' => 1,
          'high' => 1,
          'medium' => 0,
          'low' => 0,
          'info' => 0,
          'unknown' => 0
        }
      end

      let(:expected_ancestor_statistics) do
        {
          'total' => 4,
          'critical' => 2,
          'high' => 2,
          'medium' => 0,
          'low' => 0,
          'info' => 0,
          'unknown' => 0
        }
      end

      context 'when there is no vulnerability_namespace_statistic record for a group' do
        it 'creates a new record for each namespace' do
          expect { adjust_statistics }.to change { Vulnerabilities::NamespaceStatistic.count }.by(3)
        end

        it 'sets the correct values for the parent group' do
          adjust_statistics

          expect(group_statistics(sub_group)).to eq(expected_single_project_statistics.merge({
            'namespace_id' => sub_group.id,
            'traversal_ids' => sub_group.traversal_ids
          }))
        end

        it 'sets the correct values for the ancestor groups' do
          adjust_statistics

          expect(group_statistics(group)).to eq(expected_ancestor_statistics.merge({
            'namespace_id' => group.id,
            'traversal_ids' => group.traversal_ids
          }))

          expect(group_statistics(root_group)).to eq(expected_ancestor_statistics.merge({
            'namespace_id' => root_group.id,
            'traversal_ids' => root_group.traversal_ids
          }))
        end
      end

      context 'when there is already a vulnerability_namespace_statistic record for a group' do
        let!(:root_group_statistics) do
          create(:vulnerability_namespace_statistic, namespace: root_group, total: 4, info: 3, unknown: 1)
        end

        it 'sets the correct values for the group' do
          adjust_statistics

          expect(group_statistics(root_group)).to eq(expected_ancestor_statistics.merge({
            'namespace_id' => root_group.id,
            'traversal_ids' => root_group.traversal_ids
          }))
        end

        context 'when a group traversal_ids is outdated' do
          before do
            root_group_statistics.update!(traversal_ids: [22, 22, 22])
          end

          it 'sets the correct namespace_ids for the group' do
            adjust_statistics

            expect(group_statistics(root_group)).to eq(expected_ancestor_statistics.merge({
              'namespace_id' => root_group.id,
              'traversal_ids' => root_group.traversal_ids
            }))
          end
        end
      end

      context 'when there are vulnerability_statistic for an archived project' do
        before do
          sub_group_project.update!(archived: true)
          sub_group_project_statistics.update!(archived: true)
        end

        it 'excludes the statistics from archived projects' do
          adjust_statistics

          expect(group_statistics(sub_group)).to be_nil

          expect(group_statistics(group)).to eq(expected_single_project_statistics.merge({
            'namespace_id' => group.id,
            'traversal_ids' => group.traversal_ids
          }))

          expect(group_statistics(root_group)).to eq(expected_single_project_statistics.merge({
            'namespace_id' => root_group.id,
            'traversal_ids' => root_group.traversal_ids
          }))
        end
      end
    end
  end
end
