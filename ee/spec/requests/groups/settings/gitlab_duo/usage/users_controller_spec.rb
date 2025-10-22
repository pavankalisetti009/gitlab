# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuo::Usage::UsersController, feature_category: :consumables_cost_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let(:usage_billing_dev_enabled) { true }

  before do
    sign_in(user)
    stub_feature_flags(usage_billing_dev: usage_billing_dev_enabled)
  end

  describe 'GET /groups/*group_id/-/settings/gitlab_duo/usage/users/:username' do
    subject(:request) { get group_settings_gitlab_duo_usage_user_path(group, username: user) }

    context 'when user is an owner' do
      before_all do
        group.add_owner(user)
      end

      context 'when in .com', :saas do
        it 'returns 200' do
          request

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when usage_billing_dev FF is disabled' do
          let(:usage_billing_dev_enabled) { false }

          it 'renders 404' do
            request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when in Self-Managed' do
        it 'renders 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not an owner', :saas do
      before_all do
        group.add_maintainer(user)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
