# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be_with_reload(:user) { create(:user) }

  let_it_be(:group) { create(:group, :nested, developers: user) }
  let(:work_items_path) { group_work_item_path(group, work_item.iid) }

  before do
    stub_feature_flags(enforce_check_group_level_work_items_license: true)
  end

  context 'for signed in user' do
    before do
      sign_in(user)
      stub_licensed_features(epics: true)
    end

    it 'creates a group work item' do
      visit "#{group_work_items_path(group)}/new" # We don't have a route helper since routing is done via Vue

      select "Issue", from: "work-item-type"
      fill_in _("Title"), with: "Test work item"

      click_button _("Create issue")

      wait_for_requests

      within_testid("work-item-title") do
        expect(page).to have_text "Test work item"
      end
    end

    context 'for epic work items' do
      let_it_be(:label) { create(:group_label, group: group) }
      let_it_be_with_reload(:work_item) do
        create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group, labels: [label])
      end

      context 'on the work item route' do
        before do
          visit work_items_path
        end

        it_behaves_like 'work items rolled up dates'

        it 'shows the correct breadcrumbs' do
          within_testid('breadcrumb-links') do
            expect(page).to have_link(group.name, href: group_path(group))
            expect(page).to have_link('Epics', href: group_epics_path(group))
            expect(find('nav:last-of-type li:last-of-type')).to have_link(work_item.to_reference, href: work_items_path)
          end
        end
      end

      context 'on the epics route' do
        before do
          visit group_epic_path(group, work_item.iid)

          within_testid('work-item-feedback-popover') do
            find_by_testid('close-button').click
          end
        end

        it 'shows the correct breadcrumbs' do
          within_testid('breadcrumb-links') do
            expect(page).to have_link(group.name, href: group_path(group))
            expect(page).to have_link('Epics', href: "#{group_epics_path(group)}/")
            expect(find('nav:last-of-type li:last-of-type')).to have_link(work_item.to_reference,
              href: group_epic_path(group, work_item.iid))
          end
        end

        it 'shows work item labels pointing to filtered epics list' do
          within_testid('work-item-labels') do
            expect(page).to have_link(label.title, href: "#{group_epics_path(group)}?label_name[]=#{label.title}")
          end
        end

        # Make sure we render the work item under the epics route and are able to edit it.
        it_behaves_like 'work items title'
      end
    end

    context 'for other work items' do
      let_it_be(:work_item) { create(:work_item, :issue, :group_level, namespace: group) }

      before do
        visit work_items_path
      end

      it 'shows the correct breadcrumbs' do
        within_testid('breadcrumb-links') do
          expect(page).to have_link(group.name, href: group_path(group))
          expect(page).to have_link('Epics', href: group_epics_path(group))
          expect(find('nav:last-of-type li:last-of-type')).to have_link(work_item.to_reference, href: work_items_path)
        end
      end
    end

    context 'without group level work items license' do
      let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

      before do
        stub_licensed_features(epics: false)
      end

      it 'shows the correct breadcrumbs' do
        visit work_items_path
        expect(page).to have_content("Work item not found")
        expect(page).to have_content(
          "This work item is not available. It either doesn't exist or you don't " \
            "have permission to view it"
        )
      end
    end
  end
end
