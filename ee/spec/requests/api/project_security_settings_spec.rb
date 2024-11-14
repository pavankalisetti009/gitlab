# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectSecuritySettings, :aggregate_failures, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:security_setting) { create(:project_security_setting) }
  let(:project) { security_setting.project }

  describe 'GET /projects/:id/security_settings' do
    let(:url) { "/projects/#{project.id}/security_settings" }

    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        get api(url)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        stub_licensed_features(pre_receive_secret_detection: true)
      end

      it 'returns project security settings when the user has at least the Developer role' do
        project.add_developer(user)
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns 401 Unauthorized when the user has Guest role' do
        project.add_guest(user)
        get api(url, user)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'returns 404 for non-existing project' do
        project.add_developer(user)
        get api("/projects/non-existing/security_settings", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PUT /projects/:id/security_settings' do
    let(:url) { "/projects/#{project.id}/security_settings" }

    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        put api(url)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        stub_licensed_features(pre_receive_secret_detection: true)
      end

      it 'updates project security settings for users with Maintainer role' do
        project.add_maintainer(user)
        put api(url, user), params: { pre_receive_secret_detection_enabled: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['pre_receive_secret_detection_enabled']).to be(true)
      end

      it 'returns 401 Unauthorized for users with Developer role' do
        project.add_developer(user)
        put api(url, user), params: { pre_receive_secret_detection_enabled: true }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end
end
