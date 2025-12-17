# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'End of trial modal', :saas_gitlab_com_subscriptions, :js, feature_category: :acquisition do
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  context 'when duo enterprise is available' do
    context 'when widget is expired' do
      let_it_be(:group_with_expired_trial) do
        create(
          :group_with_plan,
          plan: :free_plan,
          trial: true,
          trial_starts_on: Date.current,
          trial_ends_on: 30.days.from_now,
          owners: user
        )
      end

      before do
        stub_billing_plans(group_with_expired_trial.id)
      end

      it 'shows modal and allows dismissal' do
        visit group_path(group_with_expired_trial)

        expect(page).not_to have_content('Your trial has ended')

        travel_to(31.days.from_now) do
          page.refresh

          expect(page).to have_content('Your trial has ended')

          click_link 'Explore plans'

          expect(page).not_to have_content('Your trial has ended')

          page.refresh

          expect(page).not_to have_content('Your trial has ended')
        end
      end
    end
  end
end
