# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::SecretsController, type: :request, feature_category: :secrets_management do
  let_it_be(:developer) { create(:user) }
  let_it_be(:reporter) { create(:user, :with_namespace) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:secrets_manager) { build(:project_secrets_manager, project: project) }

  shared_examples 'renders the project secrets index template' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('projects/secrets/index')
    end
  end

  shared_examples 'returns a "not found" response' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /:namespace/:project/-/secrets' do
    subject(:request) { get project_secrets_url(project), params: { project_id: project.to_param } }

    before_all do
      stub_feature_flags(secrets_manager: project)
      secrets_manager.activate!
      project.add_developer(developer)
      project.add_reporter(reporter)
      project.add_guest(guest)
    end

    context 'when all conditions are met' do
      before do
        stub_licensed_features(native_secrets_management: true)
        sign_in(reporter)
      end

      it_behaves_like 'renders the project secrets index template'
    end

    context 'when user has a role higher than reporter' do
      before do
        stub_licensed_features(native_secrets_management: true)
        sign_in(developer)
      end

      it_behaves_like 'renders the project secrets index template'
    end

    context 'when user is not Reporter+' do
      before do
        stub_licensed_features(native_secrets_management: true)
        sign_in(guest)
      end

      it_behaves_like 'returns a "not found" response'
    end

    context 'when feature flag is disabled' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager: false)
        sign_in(reporter)
      end

      it_behaves_like 'returns a "not found" response'
    end

    context 'when feature license is disabled' do
      before do
        stub_licensed_features(native_secrets_management: false)
        sign_in(reporter)
      end

      it_behaves_like 'returns a "not found" response'
    end

    context 'when secrets manager is not active' do
      before do
        stub_licensed_features(native_secrets_management: true)
        secrets_manager.update!(status: SecretsManagement::ProjectSecretsManager::STATUSES[:deprovisioning])
        sign_in(reporter)
      end

      it_behaves_like 'returns a "not found" response'
    end
  end
end
