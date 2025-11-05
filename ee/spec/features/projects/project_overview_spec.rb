# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Project overview", :js, feature_category: :source_code_management do
  context 'with premium_message_during_trial experiment', :saas, feature_category: :acquisition do
    let_it_be(:user) { create(:user, :with_namespace) }
    let_it_be(:trial_project) do
      create(
        :project, :repository,
        group:
          create(
            :group_with_plan,
            plan: :ultimate_trial_plan,
            trial: true,
            trial_starts_on: Date.current,
            trial_ends_on: 30.days.from_now,
            owners: user
          )
      )
    end

    before do
      allow(Gitlab::Experiment::Configuration).to receive(:cache).and_call_original
      stub_feature_flags(premium_message_during_trial: true)

      sign_in(user)
      visit project_path(trial_project)
    end

    it 'does not show callout when flag is on and user is not on trial' do
      expect(page).not_to have_content('Accelerate your workflow with GitLab Duo Core')
    end
  end
end
