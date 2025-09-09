# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabDuo::Usage::UsersController,
  :enable_admin_mode, feature_category: :consumables_cost_management do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:usage_billing_dev_enabled) { true }

  before do
    sign_in(admin)
    stub_feature_flags(usage_billing_dev: usage_billing_dev_enabled)
  end

  describe 'GET /admin/gitlab_duo/usage/users' do
    subject(:request) { get admin_gitlab_duo_usage_user_path(user) }

    it 'returns 200' do
      request

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'renders 404 when in .com', :saas do
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'renders 404 when unlicensed' do
      allow(License).to receive(:current).and_return(nil)
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when usage_billing_dev FF is disabled' do
      let(:usage_billing_dev_enabled) { false }

      it 'renders 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
