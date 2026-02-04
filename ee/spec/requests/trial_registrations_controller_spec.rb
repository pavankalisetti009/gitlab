# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TrialRegistrationsController, :with_trial_types, feature_category: :onboarding do
  include FullNameHelper
  include IdentityVerificationHelpers

  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
  end

  describe 'GET new' do
    let(:get_params) { {} }

    subject(:get_new) do
      get new_trial_registration_path, params: get_params
      response
    end

    context 'when the saas feature onboarding is not available' do
      let(:onboarding_enabled?) { false }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when user is not authenticated' do
      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'pushes ultimate_trial_with_dap feature flag' do
        get_new

        expect(response.body).to have_pushed_frontend_feature_flags(ultimateTrialWithDap: true)
      end

      context 'with tracking' do
        it 'tracks page render' do
          get_new

          expect_snowplow_event(
            category: described_class.name,
            action: 'render_registration_page',
            label: 'trial_registration'
          )
        end
      end
    end

    context 'when user is authenticated' do
      let(:get_params) { { some_param: '_param_' } }

      before do
        sign_in(create(:user))
      end

      it { is_expected.to redirect_to(new_trial_path(get_params)) }
    end

    describe '#ensure_first_name_and_last_name_not_empty' do
      subject(:post_create_with_empty_names) do
        post trial_registrations_path, params: { user: attributes_for(:user, first_name: '', last_name: '') }
      end

      context 'with experiment `lightweight_trial_registration_redesign`' do
        context 'when control' do
          before do
            stub_experiments(lightweight_trial_registration_redesign: :control)
          end

          it 'prevents user creation with empty first and last names' do
            expect { post_create_with_empty_names }.not_to change { User.count }
          end
        end

        context 'when candidate' do
          before do
            stub_experiments(lightweight_trial_registration_redesign: :candidate)
          end

          it 'prevents user creation with empty first and last names' do
            expect { post_create_with_empty_names }.not_to change { User.count }
          end
        end
      end
    end
  end

  describe 'POST create' do
    let(:params) { {} }
    let(:extra_params) { {} }
    let(:user_params) do
      build_stubbed(:user).slice(:first_name, :last_name, :email, :username, :password).merge(extra_params)
    end

    subject(:post_create) do
      post trial_registrations_path, params: params.merge(user: user_params)
      response
    end

    before do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    context 'with onboarding' do
      let(:extra_params) { { onboarding_status_email_opt_in: 'true' } }
      let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }
      let(:new_user_email) { user_params[:email] }
      let(:params) { glm_params }

      before do
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      it 'onboards the user' do
        post_create

        expect(response).to redirect_to(users_sign_up_welcome_path)
        created_user = User.find_by_email(new_user_email)
        expect(created_user).to be_onboarding_in_progress
        expect(created_user.onboarding_status_step_url).to eq(users_sign_up_welcome_path)
        expect(created_user.onboarding_status_initial_registration_type).to eq('trial')
        expect(created_user.onboarding_status_registration_type).to eq('trial')
        expect(created_user.onboarding_status_email_opt_in).to be(true)
        expect(created_user.onboarding_status_glm_content).to eq('_glm_content_')
        expect(created_user.onboarding_status_glm_source).to eq('_glm_source_')
      end

      context 'when lightweight_trial_registration_redesign experiment' do
        before do
          stub_experiments(lightweight_trial_registration_redesign: :candidate)
        end

        it 'is candidate redirects to trial welcome path' do
          post_create

          expect(response).to redirect_to(new_users_sign_up_trial_welcome_path)

          created_user = User.find_by_email(new_user_email)
          expect(created_user.onboarding_status_step_url).to eq(new_users_sign_up_trial_welcome_path)
        end
      end
    end

    context 'when the saas feature onboarding is not available' do
      let(:onboarding_enabled?) { false }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when the saas feature onboarding is available' do
      it { is_expected.to have_gitlab_http_status(:found) }

      it_behaves_like 'creates a user with ArkoseLabs risk band on signup request' do
        let(:user_attrs) { user_params }
        let(:registration_path) { trial_registrations_path }
      end

      context 'with snowplow tracking', :snowplow do
        it 'tracks successful form submission' do
          expect_successful_post_create

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            label: 'trial_registration',
            user: User.find_by(email: user_params[:email])
          )
        end

        context 'with email confirmation' do
          before do
            stub_application_setting(require_admin_approval_after_user_signup: false)
            stub_saas_features(identity_verification: false)
            allow(User).to receive(:allow_unconfirmed_access_for).and_return 0
          end

          context 'when email confirmation settings is set to `soft`' do
            before do
              stub_application_setting_enum('email_confirmation_setting', 'soft')
            end

            it 'does not track an almost there redirect' do
              expect_successful_post_create

              expect_no_snowplow_event(
                category: described_class.name,
                action: 'render',
                user: User.find_by(email: user_params[:email])
              )
            end
          end

          context 'when email confirmation settings is not set to `soft`' do
            before do
              stub_application_setting_enum('email_confirmation_setting', 'hard')
            end

            it 'tracks an almost there redirect' do
              expect_successful_post_create

              expect_snowplow_event(
                category: described_class.name,
                action: 'render',
                user: User.find_by(email: user_params[:email])
              )
            end
          end
        end
      end

      context 'for derivation of name' do
        it 'sets name from first and last name' do
          expect_successful_post_create

          created_user = User.find_by_email(user_params[:email])
          expect(created_user.name).to eq full_name(user_params[:first_name], user_params[:last_name])
        end
      end

      context 'when email confirmation setting is set to hard' do
        before do
          stub_application_setting_enum('email_confirmation_setting', 'hard')
        end

        it 'marks the account as unconfirmed' do
          expect_successful_post_create

          created_user = User.find_by_email(user_params[:email])
          expect(created_user).not_to be_confirmed
        end
      end

      context 'when user params are not provided' do
        subject(:post_create) { post trial_registrations_path }

        it 'raises an error' do
          expect { post_create }.to raise_error(ActionController::ParameterMissing)
        end
      end

      context 'when user is not persisted' do
        let(:user_params) { super().merge(password: '11111111') }

        it 'tracks registration error' do
          post_create

          expect_snowplow_event(
            category: 'Gitlab::Tracking::Helpers::InvalidUserErrorEvent',
            action: 'track_trial_registration_error',
            label: 'failed_creating_user'
          )
        end
      end
    end

    context 'with experiment lightweight_trial_registration_redesign' do
      let(:username) { 'test_username' }
      let(:user_params) { super().merge(username: username) }

      before do
        stub_experiments(lightweight_trial_registration_redesign: :candidate)
      end

      it 'sets name from first and last name' do
        expect_successful_post_create

        created_user = User.find_by_email(user_params[:email])
        expect(created_user.name).to eq(full_name(user_params[:first_name], user_params[:last_name]))
      end

      context 'when in control group' do
        before do
          stub_experiments(lightweight_trial_registration_redesign: :control)
        end

        it 'sets name from first and last name' do
          expect_successful_post_create

          created_user = User.find_by_email(user_params[:email])
          expect(created_user.name).to eq(full_name(user_params[:first_name], user_params[:last_name]))
        end
      end
    end

    context 'with tracking' do
      let(:experiment) { instance_double(ApplicationExperiment) }

      before do
        allow_next_instance_of(described_class) do |controller|
          # pre login
          allow(controller).to receive(:experiment).with(:lightweight_trial_registration_redesign,
            actor: nil).and_return(experiment)
          # post login
          allow(controller).to receive(:experiment).with(:lightweight_trial_registration_redesign,
            actor: instance_of(User)).and_return(experiment)
          allow(controller).to receive(:experiment).with(:premium_trial_positioning,
            actor: instance_of(User)).and_call_original
        end
        allow(experiment).to receive(:run)
      end

      it 'tracks experiment registration completion' do
        expect(experiment).to receive(:track).with(:completed_trial_registration_form)

        post_create
      end
    end

    context 'with premium_trial_positioning experiment' do
      before do
        stub_experiments(premium_trial_positioning: :control)
      end

      it 'calls the premium trial positioning experiment with the created user' do
        expect_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:experiment)
            .with(:lightweight_trial_registration_redesign, anything)
            .and_call_original

          expect(instance).to receive(:experiment)
            .with(:premium_trial_positioning, actor: instance_of(User))
            .and_call_original
        end

        expect_successful_post_create
      end
    end
  end

  def expect_successful_post_create
    expect { post_create }.to change { User.count }.by(1)
  end
end
