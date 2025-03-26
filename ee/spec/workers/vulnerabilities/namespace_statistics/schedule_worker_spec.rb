# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::ScheduleWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  let_it_be(:user_namespace) { create(:user_namespace) }
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:group_without_vulnerabilities) { create(:group) }
  let_it_be(:deleted_group) { create(:group) }

  let_it_be(:user_project) { create(:project, namespace: user_namespace) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:project_namespace) { project.project_namespace }
  let_it_be(:another_project) { create(:project, group: another_group) }
  let_it_be(:project_without_vulnerabilities) { create(:project, group: group_without_vulnerabilities) }
  let_it_be(:deleted_group_project) { create(:project, group: deleted_group) }

  describe "#perform" do
    before do
      deleted_group.namespace_details.update!(deleted_at: Time.current)
      allow(Vulnerabilities::NamespaceStatistics::AdjustmentWorker).to receive(:perform_in)
      stub_const("Vulnerabilities::NamespaceStatistics::ScheduleWorker::BATCH_SIZE", 2)
    end

    context 'when there are no vulnerability_statistics records' do
      it 'doesnt schedule an AdjustmentWorker' do
        worker.perform

        expect(Vulnerabilities::NamespaceStatistics::AdjustmentWorker)
          .not_to have_received(:perform_in)
      end
    end

    context 'when there are vulnerability_statistics records' do
      let_it_be(:vulnerability_statistic_1) { create(:vulnerability_statistic, project: user_project) }
      let_it_be(:vulnerability_statistic_2) { create(:vulnerability_statistic, project: project) }
      let_it_be(:vulnerability_statistic_3) { create(:vulnerability_statistic, project: another_project) }
      let_it_be(:vulnerability_statistic_4) { create(:vulnerability_statistic, project: deleted_group_project) }

      it 'schedules an AdjustmentWorker with the correct namespace_ids' do
        worker.perform

        # without deleted, user project namespaces. Without namespaces not in `vulnerability_statistic`
        namespace_ids = [group.id, another_group.id]
        expect(Vulnerabilities::NamespaceStatistics::AdjustmentWorker)
          .to have_received(:perform_in).with(0, namespace_ids)
      end
    end
  end
end
