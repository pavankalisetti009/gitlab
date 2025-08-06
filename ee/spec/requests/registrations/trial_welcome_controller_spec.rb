# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::TrialWelcomeController, :with_current_organization, :saas, feature_category: :onboarding do
  let_it_be(:user, reload: true) { create(:user, organizations: [current_organization]) }
  let_it_be(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }
  let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }

  let(:subscriptions_trials_enabled) { true }

  before do
    stub_saas_features(subscriptions_trials: subscriptions_trials_enabled, marketing_google_tag_manager: false)
  end

  describe 'GET #new' do
    let(:base_params) { glm_params }

    subject(:get_new) do
      get new_users_sign_up_trial_welcome_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'when authenticated' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'enables dark mode' do
        get_new

        expect(assigns(:html_class)).to eq('gl-dark')
      end

      context 'with experiment lightweight_trial_registration_redesign' do
        let(:experiment) { instance_double(ApplicationExperiment) }

        before do
          allow_next_instance_of(described_class) do |controller|
            allow(controller).to receive(:experiment).with(:lightweight_trial_registration_redesign,
              actor: user).and_return(experiment)
          end
        end

        it 'tracks render_welcome' do
          expect(experiment).to receive(:track).with(:render_welcome)

          get_new
        end
      end
    end
  end

  describe 'POST create' do
    let_it_be(:group_for_trial, reload: true) { create(:group_with_plan, plan: :free_plan, owners: user) }
    let(:default_params) do
      {
        first_name: '_first_name_',
        last_name: '_last_name_',
        company_name: '_company_name_',
        country: '_country_',
        state: '_state_',
        group_name: "group name",
        project_name: "project name",
        organization_id: current_organization.id
      }.merge(glm_params).with_indifferent_access
    end

    let(:params) { default_params }
    let(:namespace_id) { 1 }
    let(:project_id) { 1 }

    subject(:post_create) do
      post users_sign_up_trial_welcome_path, params: params
      response
    end

    context 'when authenticated', :use_clean_rails_memory_store_caching do
      before do
        login_as(user)
      end

      it "when successful" do
        expect(GitlabSubscriptions::Trials::WelcomeCreateService).to receive(:new).and_wrap_original do |method, args|
          expect(args[:params].to_h).to eq(params)
          instance = method.call(**args)

          result = ServiceResponse.success(
            message: 'Trial applied',
            payload: { namespace_id: namespace_id, project_id: project_id, add_on_purchase: add_on_purchase }
          )
          expect(instance).to receive(:execute).and_return(result)
          instance
        end

        expect(post_create).to redirect_to(namespace_project_learn_gitlab_path(namespace_id, project_id))
      end

      context 'with experiment lightweight_trial_registration_redesign' do
        let(:experiment) { instance_double(ApplicationExperiment) }

        before do
          allow_next_instance_of(described_class) do |controller|
            allow(controller).to receive(:experiment).with(:lightweight_trial_registration_redesign,
              actor: user).and_return(experiment)
          end
        end

        it 'tracks completed_group_project_creation' do
          expect_next_instance_of(GitlabSubscriptions::Trials::WelcomeCreateService,
            hash_including(params: params)) do |instance|
            result = ServiceResponse.success(
              message: 'Trial applied',
              payload: { namespace_id: group_for_trial.id, project_id: project_id, add_on_purchase: add_on_purchase }
            )
            expect(instance).to receive(:execute).and_return(result)
          end

          expect(experiment).to receive(:track).with(:completed_group_project_creation, namespace: group_for_trial)

          post_create
        end
      end

      it "when group creation fails" do
        expect(GitlabSubscriptions::Trials::WelcomeCreateService).to receive(:new).and_wrap_original do |method, args|
          expect(args[:params].to_h).to eq(params)
          instance = method.call(**args)

          result = ServiceResponse.error(
            message: 'Trial creation failed in namespace stage',
            payload: { namespace_id: nil, project_id: nil, lead_created: false,
                       model_errors: [groupName: ["group creation failed"]] }
          )
          expect(instance).to receive(:execute).and_return(result)
          instance
        end

        post_create

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(_('group creation failed'))
      end

      it "when user can not create a group" do
        expect(GitlabSubscriptions::Trials::WelcomeCreateService).to receive(:new).and_wrap_original do |method, args|
          expect(args[:params].to_h).to eq(params)
          instance = method.call(**args)

          result = ServiceResponse.error(
            message: 'Trial creation failed in namespace stage',
            reason: GitlabSubscriptions::Trials::UltimateCreateService::NOT_FOUND
          )
          expect(instance).to receive(:execute).and_return(result)
          instance
        end

        expect(post_create).to have_gitlab_http_status(:not_found)
      end

      it "when project creation fails" do
        expect(GitlabSubscriptions::Trials::WelcomeCreateService).to receive(:new).and_wrap_original do |method, args|
          expect(args[:params].to_h).to eq(params)
          instance = method.call(**args)

          result = ServiceResponse.error(
            message: 'Trial creation failed in project stage',
            payload: { namespace_id: namespace_id, project_id: nil, lead_created: false,
                       model_errors: [projectName: ["project creation failed"]] }
          )
          expect(instance).to receive(:execute).and_return(result)
          instance
        end

        expect(post_create).to have_gitlab_http_status(:ok)
        expect(response.body).to include(_('project creation failed'))
      end

      context "when resubmission" do
        let(:params) { default_params.merge(namespace_id: namespace_id) }

        it "when project creation success" do
          expect(GitlabSubscriptions::Trials::WelcomeCreateService).to receive(:new).and_wrap_original do |method, args|
            expect(args[:params].to_h).to eq(params.without(:namespace_id))
            instance = method.call(**args)

            result = ServiceResponse.success(
              message: 'Trial applied',
              payload: { namespace_id: namespace_id, project_id: project_id, lead_created: true }
            )
            expect(instance).to receive(:execute).and_return(result)
            instance
          end

          expect(post_create).to redirect_to(namespace_project_learn_gitlab_path(namespace_id, project_id))
        end
      end
    end
  end
end
