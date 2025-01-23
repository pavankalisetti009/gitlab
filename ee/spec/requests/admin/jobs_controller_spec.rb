# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::JobsController, feature_category: :fleet_visibility do
  let_it_be(:non_admin_user) { create(:user) }

  subject { response }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe 'GET #index' do
    before do
      get admin_jobs_path
    end

    context 'with a non-admin user' do
      let_it_be(:user) { non_admin_user }

      it { is_expected.to have_gitlab_http_status(:not_found) }

      context 'when assigned an admin custom role with read_admin_cicd enabled' do
        let_it_be(:role) { create(:member_role, :admin, :read_admin_cicd) }
        let_it_be(:user_member_role) { create(:user_member_role, member_role: role, user: user) }

        it { is_expected.to have_gitlab_http_status(:ok) }
      end
    end
  end
end
