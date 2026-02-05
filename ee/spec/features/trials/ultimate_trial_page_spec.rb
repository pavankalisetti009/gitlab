# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Ultimate Trial Page', :js, :saas, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  context 'when ultimate_trial_with_dap feature flag is enabled' do
    it 'shows the new title' do
      visit new_trial_path

      expect(page).to have_title('Start your free Ultimate trial')
    end
  end

  context 'when ultimate_trial_with_dap feature flag is disabled' do
    before do
      stub_feature_flags(ultimate_trial_with_dap: false)
    end

    it 'shows the duo enterprise title' do
      visit new_trial_path

      expect(page).to have_title('Start your free Ultimate and GitLab Duo Enterprise trial')
    end
  end
end
