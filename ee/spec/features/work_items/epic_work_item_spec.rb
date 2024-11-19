# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic work item', :js, feature_category: :team_planning do
  include ListboxHelpers
  include WorkItemFeedbackHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user, name: 'John') }

  let_it_be(:group) { create(:group, :nested, developers: user) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:label2) { create(:group_label, group: group) }
  let_it_be_with_reload(:work_item) do
    create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group, labels: [label])
  end

  let_it_be(:emoji_upvote) { create(:award_emoji, :upvote, awardable: work_item, user: user2) }
  let(:work_items_path) { group_epic_path(group, work_item.iid) }
  let(:list_path) { group_epics_path(group) }

  context 'for signed in user' do
    before do
      stub_feature_flags(notifications_todos_buttons: false)
      stub_licensed_features(epics: true, issuable_health_status: true)
      sign_in(user)
      visit work_items_path
      close_work_item_feedback_popover_if_present
    end

    it 'shows breadcrumb links', :aggregate_failures do
      within_testid('breadcrumb-links') do
        expect(page).to have_link(group.name, href: group_path(group))
        expect(page).to have_link('Epics', href: list_path)
        expect(find('nav:last-of-type li:last-of-type')).to have_link(work_item.to_reference,
          href: group_epic_path(group, work_item.iid))
      end
    end

    it_behaves_like 'work items title'
    it_behaves_like 'work items award emoji'
    it_behaves_like 'work items toggle status button'

    it_behaves_like 'work items todos'
    it_behaves_like 'work items lock discussion', 'epic'
    it_behaves_like 'work items confidentiality'
    it_behaves_like 'work items notifications'

    it_behaves_like 'work items assignees'
    it_behaves_like 'work items labels', 'group'
    it_behaves_like 'work items rolled up dates'
    it_behaves_like 'work items health status'
    it_behaves_like 'work items time tracking'
  end
end
