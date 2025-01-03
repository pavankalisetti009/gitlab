# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::Hierarchy, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: another_group) }
  let_it_be(:work_item) do
    create(:work_item, :epic_with_legacy_epic, namespace: group).tap do |parent|
      # child issue with legacy epic_issue relationship
      create(:work_item, :issue).tap do |work_item|
        link = create(:parent_link, work_item: work_item, work_item_parent: parent)
        create(:epic_issue, epic: parent.sync_object, issue: work_item, work_item_parent_link: link)
      end
      # child epic with legacy parent_id relationship
      create(:work_item, :epic_with_legacy_epic).tap do |work_item|
        link = create(:parent_link, work_item: work_item, work_item_parent: parent)
        work_item.sync_object.update!(parent_id: parent.sync_object.id, work_item_parent_link: link)
      end
    end
  end

  let(:params) { { operation: :move } }

  before_all do
    group.add_developer(current_user)
    another_group.add_developer(current_user)
  end

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: params
    )
  end

  describe '#after_save_commit' do
    context 'when target work item has hierarchy widget' do
      before do
        allow(target_work_item).to receive(:get_widget).with(:hierarchy).and_return(true)
      end

      it 'copies hierarchy data from work_item to target_work_item' do
        expect(callback).to receive(:handle_parent).and_call_original
        expect(callback).to receive(:handle_children).and_call_original

        source_sync_obj = work_item.sync_object
        source_work_item_children_titles = work_item.work_item_children.map(&:title)
        source_epic_titles = source_sync_obj.children.map(&:title)
        source_epic_issues_titles = source_sync_obj.issues.map(&:title)
        source_epic_parent_links = source_sync_obj.children.map(&:work_item_parent_link_id)
        source_issues_parent_links = source_sync_obj.epic_issues.map(&:work_item_parent_link_id)

        expect { callback.after_save_commit }.to not_change { Epic.count }.and(not_change { EpicIssue.count })

        target_sync_obj = target_work_item.sync_object.reload
        expect(target_sync_obj.children.map(&:title)).to match_array(source_epic_titles)
        expect(target_sync_obj.children.map(&:work_item_parent_link_id)).to match_array(source_epic_parent_links)
        expect(target_sync_obj.issues.map(&:title)).to match_array(source_epic_issues_titles)
        expect(target_sync_obj.epic_issues.map(&:work_item_parent_link_id)).to match_array(source_issues_parent_links)

        expect(target_work_item.reload.work_item_children.map(&:title)).to match_array(source_work_item_children_titles)
        expect(target_work_item.namespace.work_items).to match_array([target_work_item])

        expect(work_item.reload.work_item_children).to be_empty
        expect(source_sync_obj.reload.children).to be_empty
        expect(source_sync_obj.reload.issues).to be_empty
      end
    end

    context 'when target work item does not have hierarchy widget' do
      before do
        target_work_item.reload
        allow(target_work_item).to receive(:get_widget).with(:hierarchy).and_return(false)
      end

      it 'does not copy hierarchy data' do
        expect(callback).not_to receive(:new_work_item_child_link)
        expect(::WorkItems::ParentLink).not_to receive(:upsert_all)

        callback.after_create

        expect(target_work_item.reload.work_item_children).to be_empty
      end
    end
  end

  describe '#post_move_cleanup' do
    it 'is defined and can be called' do
      expect { callback.post_move_cleanup }.not_to raise_error
    end
  end
end
