# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::MoveService, feature_category: :team_planning do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group) }
  let_it_be(:target_group) { create(:group, parent: parent_group) }
  let_it_be(:issue_work_item) { create(:work_item, :group_level, namespace: group) }
  let_it_be(:source_namespace_member) { create(:user, reporter_of: group) }
  let_it_be(:target_namespace_member) { create(:user, reporter_of: target_group) }
  let_it_be(:namespaces_member) { create(:user, developer_of: [group, target_group]) }

  let(:original_work_item) { issue_work_item }
  let(:target_namespace) { target_group.reload }

  let(:service) do
    described_class.new(
      work_item: original_work_item,
      target_namespace: target_namespace,
      current_user: current_user
    )
  end

  before do
    stub_licensed_features(epics: true)
  end

  context 'when user does not have permissions' do
    context 'when user cannot read original work item' do
      let(:current_user) { target_namespace_member }

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::MoveError, 'Cannot move work item due to insufficient permissions!'
        )
      end
    end

    context 'when user cannot create work items in target namespace' do
      let(:current_user) { source_namespace_member }

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::MoveError, 'Cannot move work item due to insufficient permissions!'
        )
      end
    end
  end

  context 'when user has permission to move work item' do
    let(:current_user) { namespaces_member }

    context 'without group level work item license' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::MoveError, 'Cannot move work item due to insufficient permissions!'
        )
      end
    end

    context 'when moving to a pending delete group' do
      before do
        create(:group_deletion_schedule,
          group: target_namespace,
          marked_for_deletion_on: 5.days.from_now,
          deleting_user: current_user
        )
      end

      after do
        target_namespace.deletion_schedule.destroy!
      end

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::MoveError, 'Cannot move work item to target namespace as it is pending deletion.'
        )
      end
    end

    context 'when cloning work item with success' do
      it 'increases the target namespace work items count by 1' do
        expect do
          service.execute
        end.to change { target_namespace.work_items.count }.by(1)
      end

      it 'returns a new work item with the same attributes' do
        new_work_item = service.execute

        expect(new_work_item).to be_persisted
        expect(new_work_item).to have_attributes(
          title: original_work_item.title,
          description: original_work_item.description,
          author: original_work_item.author,
          work_item_type: original_work_item.work_item_type,
          project: nil,
          namespace: target_namespace
        )
      end
    end
  end
end
