# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::ConfigurationController, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }

  before do
    stub_licensed_features(security_attributes: true, security_dashboard: true)

    sign_in(user)
  end

  describe '#show', :aggregate_failures do
    subject(:request) { get group_security_configuration_path(group) }

    context 'with authorized user' do
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_maintainer(user)
        sign_in(user)
      end

      it 'returns 200 response' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with unauthorized user' do
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_developer(user)
        sign_in(user)
      end

      it 'returns 403 response' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when security attributes feature is not available' do
      before_all do
        group.add_maintainer(user)
        sign_in(user)
      end

      before do
        stub_licensed_features(security_attributes: false)
      end

      it 'returns 403 response' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
