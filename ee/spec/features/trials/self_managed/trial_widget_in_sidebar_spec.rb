# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Widget in Sidebar', :js, :without_license, feature_category: :acquisition do
  include Features::TrialWidgetHelpers

  let_it_be(:user) { create(:admin) }
  let_it_be(:license) { create(:license, :ultimate_trial) }

  before do
    sign_in(user)
    enable_admin_mode!(user)
  end

  context 'when trial is active' do
    it 'shows the correct days remaining on the first day of trial' do
      freeze_time do
        visit root_path

        expect_widget_title_to_be('GitLab Ultimate trial')
        expect_widget_to_have_content('30 days left in trial')
      end
    end

    it 'shows the correct trial type and days remaining' do
      travel_to(15.days.from_now) do
        visit root_path

        expect_widget_title_to_be('GitLab Ultimate trial')
        expect_widget_to_have_content('15 days left in trial')
      end

      travel_to(29.days.from_now) do
        visit root_path

        expect_widget_title_to_be('GitLab Ultimate trial')
        expect_widget_to_have_content('1 days left in trial')
      end
    end
  end

  context 'when trial is expired' do
    it 'shows upgrade after trial expiration' do
      travel_to(31.days.from_now) do
        visit root_path

        expect_widget_title_to_be('Your trial of GitLab Ultimate has ended')
        expect_widget_to_have_content('Upgrade')
      end
    end

    it 'and allows dismissal on the first day after trial expiration' do
      travel_to(31.days.from_now) do
        visit root_path

        expect_widget_title_to_be('Your trial of GitLab Ultimate has ended')
        expect_widget_to_have_content('Upgrade')

        dismiss_widget

        expect(page).not_to have_content('Upgrade')

        page.refresh

        expect(page).not_to have_content('Upgrade')
      end
    end
  end
end
