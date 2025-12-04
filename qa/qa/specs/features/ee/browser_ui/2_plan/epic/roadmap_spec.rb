# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :portfolio_management do
    describe 'Epics roadmap' do
      include QA::Support::Dates

      let(:group) { create(:group, name: "group-to-test-epic-roadmap-#{SecureRandom.hex(4)}") }
      let!(:epic) do
        create(:work_item_epic,
          group: group,
          title: 'Work Item Epic created via API to test roadmap',
          is_fixed: true,
          start_date: current_date_yyyy_mm_dd_iso,
          due_date: next_month_yyyy_mm_dd_iso)
      end

      before do
        Flow::Login.sign_in
      end

      it 'presents epic on roadmap', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347992',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/16739',
          type: :investigating,
          only: { subdomain: :staging }
        } do
        page.visit("#{group.web_url}/-/roadmap")

        EE::Page::Group::Roadmap.perform do |roadmap|
          expect(roadmap).to have_epic(epic)
        end
      end
    end
  end
end
