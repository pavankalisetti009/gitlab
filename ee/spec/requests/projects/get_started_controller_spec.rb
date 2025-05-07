# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GetStartedController, :saas, feature_category: :onboarding do
  describe 'GET /:namespace/:project/-/get_started' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let(:onboarding_enabled?) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled?)
    end

    subject(:get_show) do
      get project_get_started_path(project), params: { project_id: project.to_param }

      response
    end

    context 'for unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'for authenticated user' do
      before do
        sign_in(user)
      end

      context 'when learn gitlab is available' do
        before do
          create(:onboarding_progress, namespace: namespace)
        end

        it { is_expected.to render_template(:show) }

        context 'when onboarding is not available' do
          let(:onboarding_enabled?) { false }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when learn_gitlab_redesign feature flag is disabled' do
          before do
            stub_feature_flags(learn_gitlab_redesign: false)
          end

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end

      context 'when namespace is not onboarding' do
        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end
end
