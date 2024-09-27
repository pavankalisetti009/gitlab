# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Free Access Ending alert', :saas, :js, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: [user]) }
  let_it_be(:duo_pro_addon) { create(:gitlab_subscription_add_on, :gitlab_duo_pro) }

  before do
    sign_in(user)
  end

  context 'when dismiss button clicked' do
    it 'is dismissed' do
      visit group_path(group)
      dismiss_button.click

      wait_for_all_requests

      expect_group_page_for(group)
      expect_banner_to_be_absent
    end

    it 'remains dismissed' do
      visit group_path(group)
      dismiss_button.click

      wait_for_all_requests

      visit group_path(group)

      expect_group_page_for(group)
      expect_banner_to_be_absent
    end
  end

  def dismiss_button
    find_by_testid("hide-duo-free-access-ending-banner")
  end

  def expect_group_page_for(group)
    expect(page).to have_text group.name
    expect(page).to have_text "Group ID: #{group.id}"
  end

  def expect_banner_to_be_absent
    expect(page).not_to have_text 'Free access to GitLab Duo is ending soon'
    expect(page).not_to have_text <<~TEXT.strip
    All GitLab Duo features including GitLab Duo Chat will transition to paid features
    on 2024-10-17. To ensure continued access and use for your team, you can purchase
    GitLab Duo Pro seats.
    TEXT
  end
end
