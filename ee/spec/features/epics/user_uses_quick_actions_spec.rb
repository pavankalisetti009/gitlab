# frozen_string_literal: true

require 'spec_helper'

# Epics quick actions functionality are covered on unit test specs. These
# are added just to test frontend features at least once, before adding more
# specs to this file please take into account if there is any behaviour
# different from the current ones that needs to be tested.
RSpec.describe 'Epics > User uses quick actions', :js, feature_category: :portfolio_management do
  include Features::NotesHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:epic_1) { create(:epic, group: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }

  before do
    stub_licensed_features(epics: true, subepics: true)
    stub_feature_flags(namespace_level_work_items: false, work_item_epics: false)
    sign_in(reporter)
  end

  context 'on epic note' do
    it 'applies quick action' do
      # TODO: remove threshold after epic-work item sync
      # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(140)
      epic_2 = create(:epic, group: group)
      visit group_epic_path(group, epic_2)
      wait_for_requests

      add_note("new note \n\n/parent_epic #{epic_1.to_reference}")

      wait_for_requests
      expect(epic_2.reload.parent).to eq(epic_1)
      expect(page).to have_content("added #{epic_1.work_item.to_reference} as parent epic")
    end
  end
end
