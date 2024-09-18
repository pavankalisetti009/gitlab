# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::CloneService, feature_category: :team_planning do
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
          described_class::CloneError, 'Cannot clone work item due to insufficient permissions!'
        )
      end
    end

    context 'when user cannot create work items in target namespace' do
      let(:current_user) { source_namespace_member }

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::CloneError, 'Cannot clone work item due to insufficient permissions!'
        )
      end
    end
  end

  context 'when user has permission to clone work item' do
    let(:current_user) { namespaces_member }

    context 'without group level work item license' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::CloneError, 'Cannot clone work item due to insufficient permissions!'
        )
      end
    end

    context 'when cloning to a pending delete group' do
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
          described_class::CloneError, 'Cannot clone work item to target namespace as it is pending deletion.'
        )
      end
    end

    context 'when cloning work item with success' do
      let(:expected_original_work_item_state) { Issue.available_states[:opened] }
      let!(:original_work_item_attrs) do
        {
          title: original_work_item.title,
          description: original_work_item.description,
          author: current_user,
          work_item_type: original_work_item.work_item_type,
          state_id: Issue.available_states[:opened],
          updated_by: current_user,
          last_edited_at: nil,
          last_edited_by: nil,
          closed_at: nil,
          closed_by: nil,
          duplicated_to_id: nil,
          moved_to_id: nil,
          promoted_to_epic_id: nil,
          external_key: nil,
          upvotes_count: 0,
          blocking_issues_count: 0,
          project: target_namespace.try(:project),
          namespace: target_namespace
        }
      end

      it_behaves_like 'cloneable and moveable work item'

      context 'with specific widgets' do
        let!(:assignees) { [source_namespace_member, target_namespace_member, namespaces_member] }

        def set_assignees
          original_work_item.assignee_ids = assignees.map(&:id)
        end

        it_behaves_like 'cloneable and moveable widget data'
      end
    end
  end
end
