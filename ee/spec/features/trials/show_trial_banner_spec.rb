# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Show trial banner', :js, feature_category: :subscription_management do
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:ultimate_plan) { create(:ultimate_plan) }

  before do
    stub_signing_key
    stub_get_billing_account_details
    stub_application_setting(check_namespace_plan: true)
    allow(Gitlab).to receive(:com?).and_return(true).at_least(:once)
    stub_billing_plans(nil)

    sign_in(user)
  end

  context "when user's trial is active" do
    before do
      create(:gitlab_subscription, :active_trial, namespace: user.namespace, hosted_plan: ultimate_plan)
      stub_billing_plans(user.namespace_id)
      stub_subscription_management_data(user.namespace_id)
      stub_temporary_extension_data(user.namespace_id)
    end

    it 'renders congratulations banner for user in profile billing page' do
      visit profile_billings_path(trial: true)

      expires_on = user.namespace.trial_ends_on.iso8601
      message = format(
        s_(
          'Congratulations, your free Ultimate and GitLab Duo Enterprise trial is activated ' \
            'and will expire on %{exp_date}. The new licenses might take a minute to show on the page. To give ' \
            'members access to new GitLab Duo Enterprise features, assign them to GitLab Duo Enterprise seats.'
        ),
        exp_date: expires_on
      )

      expect(find_by_testid('trial-alert').text).to have_content(message)
    end

    context 'with the duo_enterprise_trials feature flag off' do
      before do
        stub_feature_flags(duo_enterprise_trials: false)
      end

      it 'renders congratulations banner for user in profile billing page' do
        visit profile_billings_path(trial: true)

        expect(page).to have_content('Congratulations, your free trial is activated.')
      end
    end
  end

  context "when group's trial is active" do
    before do
      group.add_owner(user)
      create(:gitlab_subscription, :active_trial, namespace: group, hosted_plan: ultimate_plan)
      stub_billing_plans(group.id)
      stub_subscription_management_data(group.id)
      stub_temporary_extension_data(group.id)
    end

    it 'renders congratulations banner for group in group details page' do
      visit group_path(group, trial: true)

      expires_on = group.trial_ends_on.iso8601
      message = format(
        s_(
          'Congratulations, your free Ultimate and GitLab Duo Enterprise trial is activated ' \
            'and will expire on %{exp_date}. The new licenses might take a minute to show on the page. To give ' \
            'members access to new GitLab Duo Enterprise features, assign them to GitLab Duo Enterprise seats.'
        ),
        exp_date: expires_on
      )

      expect(find_by_testid('trial-alert').text).to have_content(message)
    end

    context 'with the duo_enterprise_trials feature flag off' do
      before do
        stub_feature_flags(duo_enterprise_trials: false)
      end

      it 'renders congratulations banner for group in group details page' do
        visit group_path(group, trial: true)

        expect(find_by_testid('trial-alert').text).to have_content('Congratulations, your free trial is activated.')
      end

      it 'does not render congratulations banner for group in group billing page' do
        visit group_billings_path(group, trial: true)

        expect(page).not_to have_content('Congratulations, your free trial is activated.')
      end
    end

    it 'does not render congratulations banner for group in group billing page' do
      visit group_billings_path(group, trial: true)

      expires_on = group.trial_ends_on.iso8601
      message = format(
        s_(
          'Congratulations, your free Ultimate and GitLab Duo Enterprise trial is activated ' \
            'and will expire on %{exp_date}. The new licenses might take a minute to show on the page. To give ' \
            'members access to new GitLab Duo Enterprise features, assign them to GitLab Duo Enterprise seats.'
        ),
        exp_date: expires_on
      )

      expect(page).not_to have_content(message)
    end
  end
end
