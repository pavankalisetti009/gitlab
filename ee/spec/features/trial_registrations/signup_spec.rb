# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Sign Up', :with_trial_types, :with_current_organization, :saas, feature_category: :acquisition do
  include IdentityVerificationHelpers

  before do
    stub_application_setting(require_admin_approval_after_user_signup: false)
  end

  let_it_be(:new_user) { build_stubbed(:user) }

  describe 'on GitLab.com' do
    context 'with invalid email', :js do
      it_behaves_like 'user email validation' do
        let(:path) { new_user_registration_path }
      end
    end

    context 'with the unavailable username' do
      let(:existing_user) { create(:user) }

      it 'shows the error about existing username' do
        visit new_trial_registration_path
        click_on 'Continue'

        fill_in 'new_user_username', with: existing_user[:username]

        expect(page).to have_content('Username is already taken.')
      end
    end

    context 'when email is passed in the path', :js do
      it 'prefills the email form field' do
        visit new_trial_registration_path(email: 'foobar@email.com')

        expect(page).to have_field('Email', with: 'foobar@email.com')
      end
    end

    it_behaves_like 'creates a user with ArkoseLabs risk band' do
      let(:signup_path) { new_trial_registration_path }
      let(:user_email) { new_user.email }
      let(:fill_and_submit_signup_form) do
        fill_in_sign_up_form(new_user)
      end
    end

    context 'when reCAPTCHA is enabled', :js do
      before do
        stub_application_setting(recaptcha_enabled: true)
      end

      it 'creates the user', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/7605' do
        visit new_trial_registration_path

        expect { fill_in_sign_up_form(new_user) }.to change { User.count }
      end

      context 'when reCAPTCHA verification fails' do
        before do
          allow_next_instance_of(TrialRegistrationsController) do |instance|
            allow(instance).to receive(:verify_recaptcha).and_return(false)
          end
        end

        it 'does not create the user' do
          visit new_trial_registration_path

          expect { fill_in_sign_up_form(new_user) }.not_to change { User.count }
          expect(page).to have_content(_('There was an error with the reCAPTCHA. Please solve the reCAPTCHA again.'))
        end
      end
    end

    context 'when experiment `lightweight_trial_registration_redesign` is candidate', :js, experiment_tracking: 2 do
      include IdentityVerificationHelpers

      let_it_be(:user) { create(:user) }
      let(:user_email) { new_user.email }

      before do
        stub_feature_flags(lightweight_trial_registration_redesign: true)

        stub_application_setting_enum('email_confirmation_setting', 'hard')

        # The groups_and_projects_controller (on `click_on 'Create project'`) is over
        # the query limit threshold, so we have to adjust it.
        # https://gitlab.com/gitlab-org/gitlab/-/issues/340302
        allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(163)

        subscription_portal_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

        stub_request(:post, "#{subscription_portal_url}/trials")

        allow_next_instance_of(GitlabSubscriptions::CreateLeadService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.success(
              message: 'Trial applied',
              payload: {
                namespace: 1,
                project: 1
              }
            ))
        end

        allow_next_instance_of(GitlabSubscriptions::Trials::ApplyTrialService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        allow(GitlabSubscriptions::Trials).to receive(:namespace_eligible?).and_return(true)
      end

      it 'goes through the experiment trial registration flow' do
        expect_next_instance_of(GitlabSubscriptions::CreateLeadService) do |service|
          expect(service).to receive(:execute) do |params|
            trial_user = params[:trial_user]
            expect(trial_user[:first_name]).to be_present, "Expected first_name to be present in trial_user params"
            expect(trial_user[:last_name]).to be_present, "Expected last_name to be present in trial_user params"

            ServiceResponse.success
          end
        end

        visit new_trial_registration_path

        # Step 1
        expect(page).to have_content('Get Started with GitLab')
        expect(page).to have_content('First name')
        expect(page).to have_content('Last name')

        fill_in 'new_user_first_name', with: new_user.first_name
        fill_in 'new_user_last_name', with: new_user.last_name
        fill_in 'new_user_username', with: new_user.username
        fill_in 'new_user_email', with: new_user.email
        fill_in 'new_user_password', with: new_user.password

        click_button _('Continue')

        # Step 2
        expect(page).to have_content('Help us keep GitLab secure')
        expect(page).not_to have_content('You are signed in as')

        fill_in 'verification_code', with: email_verification_code

        click_button _('Verify email address')

        # Step 3
        expect(page).to have_content('Verification successful')

        wait_for_all_requests

        # Step 4
        expect(page).to have_content('Welcome to GitLab')
        expect(page).to have_content('Help us personalize your GitLab experience by answering a few questions')
        expect(page).to have_current_path(new_users_sign_up_trial_welcome_path)

        wait_for_all_requests

        select_from_listbox 'Software Developer', from: 'Select a role'
        select_from_listbox 'My team', from: 'Please select'
        select_from_listbox 'I want to move my repository to GitLab from somewhere else', from: 'Select a reason'

        select_from_listbox 'United States of America', from: 'Select a country or region'
        select_from_listbox 'California', from: 'Select state or province'

        fill_in 'company_name', with: 'My Company'
        fill_in 'group_name', with: 'My Group'
        fill_in 'project_name', with: 'My Project'

        click_button _('Continue to GitLab')

        wait_for_all_requests

        expect(page).to have_content('Get started')

        is_expected.to have_tracked_experiment(:lightweight_trial_registration_redesign, [
          :assignment,
          :completed_trial_registration_form,
          :completed_identity_verification,
          :render_welcome,
          { action: :completed_group_project_creation, namespace: Group.last },
          :render_get_started
        ])
      end

      it 'when model errors occur form can be resubmitted' do
        sign_in(user)

        visit new_users_sign_up_trial_welcome_path

        select_from_listbox 'Software Developer', from: 'Select a role'
        select_from_listbox 'My team', from: 'Please select'
        select_from_listbox 'I want to move my repository to GitLab from somewhere else', from: 'Select a reason'

        select_from_listbox 'United States of America', from: 'Select a country or region'
        select_from_listbox 'California', from: 'Select state or province'

        fill_in 'company_name', with: 'My Company'
        fill_in 'group_name', with: 'My Group'
        fill_in 'project_name', with: 'My Project*'

        click_button _('Continue to GitLab')

        expect(find_by_testid("group-name-input").disabled?).to be(true)

        fill_in 'project_name', with: 'My Project'

        group_count = Group.count
        click_button _('Continue to GitLab')

        wait_for_all_requests

        expect(group_count).to eq(Group.count)
      end

      context 'when trial submission fails', :js do
        let_it_be(:user) { create(:user) }

        before do
          allow_next_instance_of(GitlabSubscriptions::CreateLeadService) do |service|
            allow(service).to receive(:execute)
              .and_return(ServiceResponse.error(message: 'Trial failed'))
          end
        end

        it 'can be retried successfully' do
          sign_in(user)

          visit new_users_sign_up_trial_welcome_path

          select_from_listbox 'Software Developer', from: 'Select a role'
          select_from_listbox 'My team', from: 'Please select'
          select_from_listbox 'I want to move my repository to GitLab from somewhere else', from: 'Select a reason'

          select_from_listbox 'United States of America', from: 'Select a country or region'
          select_from_listbox 'California', from: 'Select state or province'

          fill_in 'company_name', with: 'My Company'
          fill_in 'group_name', with: 'My Group'
          fill_in 'project_name', with: 'My Project'

          click_button _('Continue to GitLab')

          wait_for_all_requests

          expect(page).to have_content("Trial registration unsuccessful")

          allow(GitlabSubscriptions::Trials).to receive(:namespace_eligible?).with(Group.last).and_return(true)

          expect_next_instance_of(GitlabSubscriptions::CreateLeadService) do |service|
            expect(service)
              .to receive(:execute).with({ trial_user: trial_user_params }).and_return(ServiceResponse.success)
          end

          click_button _('Resubmit request')

          wait_for_all_requests

          expect(page).to have_content('Get started')
        end

        def trial_user_params
          ActionController::Parameters.new(
            company_name: 'My Company',
            first_name: user.first_name,
            last_name: user.last_name,
            work_email: user.email,
            uid: user.id,
            country: 'US',
            state: 'CA',
            provider: 'gitlab',
            product_interaction: 'Experiment - SaaS Trial',
            setup_for_company: true,
            role: 'software_developer',
            gitlab_com_trial: true,
            skip_email_confirmation: true,
            jtbd: 'move_repository'
          ).permit!
        end
      end
    end
  end
end
