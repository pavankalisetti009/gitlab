# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::Transition, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'associations' do
    it { is_expected.to belong_to(:promoted_to_epic).class_name('Epic') }
  end

  # Syncing via `trigger_sync_issues_dates_with_work_item_dates_sources`
  describe 'syncs to work_item_transition from issue' do
    let_it_be(:epic) { create(:epic, group: group) }

    it 'syncs promoted_to_epic_id' do
      work_item = create(:work_item, :issue, project: project, promoted_to_epic: epic)

      expect(work_item.work_item_transition.promoted_to_epic).to eq(epic)

      work_item.update!(promoted_to_epic: nil)

      expect(work_item.reload.work_item_transition.promoted_to_epic).to be_nil
    end
  end
end
