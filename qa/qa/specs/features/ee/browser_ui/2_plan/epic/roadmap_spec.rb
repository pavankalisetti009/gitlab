# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', product_group: :product_planning do
    describe 'Epics roadmap' do
      include Support::Dates

      let(:epic) do
        create(:epic,
          title: 'Epic created via API to test roadmap',
          start_date_is_fixed: true,
          start_date_fixed: current_date_yyyy_mm_dd,
          due_date_is_fixed: true,
          due_date_fixed: next_month_yyyy_mm_dd)
      end

      before do
        Flow::Login.sign_in
      end

      it 'presents epic on roadmap', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347992' do
        page.visit("#{epic.group.web_url}/-/roadmap")

        EE::Page::Group::Roadmap.perform do |roadmap|
          expect(roadmap).to have_epic(epic)
        end
      end
    end
  end
end
