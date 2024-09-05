# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::SecretDetectionConfigurationController,
  feature_category: :secret_detection,
  type: :request do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  describe 'GET #show' do
    before do
      stub_licensed_features(security_dashboard: true, pre_receive_secret_detection: true)
      login_as(user)
    end

    context 'when feature is available' do
      context 'when user is authorized' do
        before_all do
          project.add_developer(user)
        end

        it 'can access page' do
          get project_security_configuration_secret_detection_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user is not authorized' do
        before_all do
          project.add_guest(user)
        end

        it 'sees a 404 error' do
          get project_security_configuration_secret_detection_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when feature is not available' do
      context "when license doesn't support the feature" do
        before do
          stub_licensed_features(pre_receive_secret_detection: false)
        end

        before_all do
          project.add_developer(user)
        end

        it 'sees a 404 error' do
          get project_security_configuration_secret_detection_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context "when feature flag is disabled" do
        before do
          stub_licensed_features(security_dashboard: true, pre_receive_secret_detection: true)
          stub_feature_flags(secret_detection_project_level_exclusions: false)
        end

        before_all do
          project.add_developer(user)
        end

        it 'sees a 404 error' do
          get project_security_configuration_secret_detection_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
