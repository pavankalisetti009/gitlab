# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SecretsController, feature_category: :secrets_management do
  let_it_be(:developer) { create(:user) }
  let_it_be(:reporter) { create(:user, :with_namespace) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:group) { create(:group) }

  shared_examples 'group secrets manager page' do
    it 'renders the group secrets index template' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('groups/secrets/index')
    end
  end

  shared_examples 'page not found' do
    it 'returns a "not found" response' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /:namespace/:group/-/secrets' do
    subject(:request) { get group_secrets_url(group), params: { group_id: group.to_param } }

    before_all do
      stub_feature_flags(group_secrets_manager: group)
      group.add_developer(developer)
      group.add_reporter(reporter)
      group.add_guest(guest)
    end

    context 'when all conditions are met' do
      before do
        stub_licensed_features(native_secrets_management: true)
        sign_in(reporter)
      end

      it_behaves_like 'group secrets manager page'
    end

    context 'when user has a role higher than reporter' do
      before do
        stub_licensed_features(native_secrets_management: true)
        sign_in(developer)
      end

      it_behaves_like 'group secrets manager page'
    end

    context 'when user is not Reporter+' do
      before do
        stub_licensed_features(native_secrets_management: true)
        sign_in(guest)
      end

      it_behaves_like 'page not found'
    end

    context 'when feature flag is disabled' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(group_secrets_manager: false)
        sign_in(reporter)
      end

      it_behaves_like 'page not found'
    end

    context 'when feature license is disabled' do
      before do
        stub_licensed_features(native_secrets_management: false)
        sign_in(reporter)
      end

      it_behaves_like 'page not found'
    end
  end
end
