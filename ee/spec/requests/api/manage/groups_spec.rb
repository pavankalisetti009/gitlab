# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Manage::Groups, :aggregate_failures, feature_category: :system_access do
  include Auth::DpopTokenHelper

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: current_user, scopes: [:api]) }

  subject(:get_request) do
    get(api(path, personal_access_token: personal_access_token), headers: dpop_headers_for(current_user))
  end

  before_all do
    group.add_owner(current_user)
  end

  shared_examples 'a manage groups GET endpoint' do
    context "when feature flag is disabled" do
      before do
        stub_feature_flags(manage_pat_by_group_owners_ready: false)
      end

      it 'returns 404 not found' do
        get_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when unauthorized user' do
      let_it_be(:unauthorized_user) { create(:user) }
      let_it_be(:personal_access_token) { create(:personal_access_token, user: unauthorized_user, scopes: [:api]) }

      it 'returns 403 for unauthorized user' do
        get(api(path, personal_access_token: personal_access_token), headers: dpop_headers_for(unauthorized_user))

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /groups/:id/manage/personal_access_tokens' do
    let_it_be(:path) { "/groups/#{group.id}/manage/personal_access_tokens" }

    let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }

    let_it_be(:active_token1) { create(:personal_access_token, user: user, scopes: [:api]) }
    let_it_be(:active_token2) { create(:personal_access_token, user: user, scopes: [:api]) }
    let_it_be(:expired_token1) { create(:personal_access_token, user: user, expires_at: 1.year.ago) }
    let_it_be(:expired_token2) { create(:personal_access_token, user: user, expires_at: 1.year.ago) }
    let_it_be(:revoked_token1) { create(:personal_access_token, user: user, revoked: true) }
    let_it_be(:revoked_token2) { create(:personal_access_token, user: user, revoked: true) }

    let_it_be(:created_2_days_ago_token) { create(:personal_access_token, user: user, created_at: 2.days.ago) }
    let_it_be(:named_token) { create(:personal_access_token, user: user,  name: 'test_1') }
    let_it_be(:last_used_2_days_ago_token) { create(:personal_access_token, user: user, last_used_at: 2.days.ago) }
    let_it_be(:last_used_2_months_ago_token) do
      create(:personal_access_token, user: user, last_used_at: 2.months.ago)
    end

    let_it_be(:created_at_asc) do
      [
        created_2_days_ago_token,
        active_token1,
        active_token2,
        expired_token1,
        expired_token2,
        revoked_token1,
        revoked_token2,
        named_token,
        last_used_2_days_ago_token,
        last_used_2_months_ago_token
      ]
    end

    let_it_be(:non_enterprise_user) { create(:user) }
    # Token which should not be returned in any responses
    let_it_be(:non_enterprise_token) { create(:personal_access_token, user: non_enterprise_user, scopes: [:api]) }

    it_behaves_like 'an access token GET API with access token params'
    it_behaves_like 'a manage groups GET endpoint'

    it 'returns 404 for non-existing group' do
      get(api(
        "/groups/#{non_existing_record_id}/manage/personal_access_tokens",
        personal_access_token: personal_access_token
      ), headers: dpop_headers_for(current_user))

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /groups/:id/manage/resource_access_tokens' do
    let_it_be(:path) { "/groups/#{group.id}/manage/resource_access_tokens" }

    let_it_be(:group_bot) { create(:user, :project_bot, bot_namespace: group, developer_of: group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:project_bot) do
      create(:user, :project_bot, bot_namespace: project.project_namespace, developer_of: project)
    end

    let_it_be(:active_token1) { create(:personal_access_token, user: project_bot) }
    let_it_be(:active_token2) { create(:personal_access_token, user: group_bot) }
    let_it_be(:expired_token1) { create(:personal_access_token, user: group_bot, expires_at: 1.year.ago) }
    let_it_be(:expired_token2) { create(:personal_access_token, user: group_bot, expires_at: 1.year.ago) }
    let_it_be(:revoked_token1) { create(:personal_access_token, user: group_bot, revoked: true) }
    let_it_be(:revoked_token2) { create(:personal_access_token, user: group_bot, revoked: true) }
    let_it_be(:created_2_days_ago_token) { create(:personal_access_token, user: project_bot, created_at: 2.days.ago) }
    let_it_be(:named_token) { create(:personal_access_token, user: group_bot, name: "Test token") }
    let_it_be(:last_used_2_days_ago_token) { create(:personal_access_token, user: group_bot, last_used_at: 2.days.ago) }
    let_it_be(:last_used_2_months_ago_token) do
      create(:personal_access_token, user: group_bot, last_used_at: 2.months.ago)
    end

    let_it_be(:created_at_asc) do
      [
        created_2_days_ago_token,
        active_token1,
        active_token2,
        expired_token1,
        expired_token2,
        revoked_token1,
        revoked_token2,
        named_token,
        last_used_2_days_ago_token,
        last_used_2_months_ago_token
      ]
    end

    let_it_be(:other_group_bot) { create(:user, :project_bot, bot_namespace: create(:group)) }

    # Tokens which should not be returned in any responses
    let_it_be(:excluded_token1) { create(:personal_access_token, user: current_user) }
    let_it_be(:excluded_token2) { create(:personal_access_token, user: create(:user, :service_account)) }
    let_it_be(:excluded_token3) { create(:personal_access_token, user: other_group_bot) }

    it_behaves_like 'an access token GET API with access token params'
    it_behaves_like 'a manage groups GET endpoint'

    it 'returns 404 for non-existing group' do
      get(api(
        "/groups/#{non_existing_record_id}/manage/resource_access_tokens",
        personal_access_token: personal_access_token
      ), headers: dpop_headers_for(current_user))

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns the expected response for group tokens' do
      get api(path, personal_access_token: personal_access_token), params: { sort: 'created_at_desc' },
        headers: dpop_headers_for(current_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/resource_access_tokens')
      expect(json_response[0]['id']).to eq(last_used_2_months_ago_token.id)
      expect(json_response[0]['resource_type']).to eq('group')
      expect(json_response[0]['resource_id']).to eq(group.id)
    end

    it 'returns the expected response for project tokens' do
      get(api(path, personal_access_token: personal_access_token), params: { sort: 'created_at_asc' },
        headers: dpop_headers_for(current_user))

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/resource_access_tokens')
      expect(json_response[0]['id']).to eq(created_2_days_ago_token.id)
      expect(json_response[0]['resource_type']).to eq('project')
      expect(json_response[0]['resource_id']).to eq(project.id)
    end

    it 'avoids N+1 queries' do
      dpop_header_val = dpop_headers_for(current_user)

      get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
      end

      other_bot = create(:user, :project_bot, bot_namespace: group, developer_of: group)
      create(:personal_access_token, user: other_bot)

      expect do
        get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
      end.not_to exceed_all_query_limit(control)
    end
  end

  describe 'GET /groups/:id/manage/ssh_keys' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:path) { "/groups/#{group.id}/manage/ssh_keys" }

    it 'throws not found error for a non existent group' do
      get(api("/groups/#{non_existing_record_id}/manage/ssh_keys"), headers: dpop_headers_for(current_user))

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it_behaves_like 'a manage groups GET endpoint'

    context 'when group has no enterprise user associated' do
      let_it_be(:user) { create(:user) }
      let_it_be(:ssh_key) { create(:personal_key, user: user) }

      it 'returns empty response for group which has no enterprise user associated' do
        group.add_developer(user)

        get(api(path, personal_access_token: personal_access_token), headers: dpop_headers_for(current_user))

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq([])
      end
    end

    context 'when group has enterprise_user associated' do
      let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }

      it "returns the ssh_keys for the group" do
        ssh_key = create(:personal_key, user: user)

        get(api(path, personal_access_token: personal_access_token), headers: dpop_headers_for(current_user))

        expect(response).to have_gitlab_http_status(:ok)
        expect_paginated_array_response_contain_exactly(ssh_key.id)
        expect(json_response[0]['user_id']).to eq(user.id)
      end

      it 'avoids N+1 queries' do
        dpop_header_val = dpop_headers_for(current_user)
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
        end

        user2 = create(:enterprise_user, enterprise_group: group)
        create(:personal_key, user: user2)

        expect do
          get(api(path, personal_access_token: personal_access_token), headers: dpop_header_val)
        end.not_to exceed_all_query_limit(control)
      end

      context 'with filter params', :freeze_time do
        subject(:get_request) do
          get api(path, personal_access_token: personal_access_token), params: params,
            headers: dpop_headers_for(current_user)
        end

        let(:params) { {} }

        context 'when created_at date filters' do
          let_it_be(:ssh_key_created_1_day_ago) { create(:personal_key, user: user, created_at: 1.day.ago.to_date) }
          let_it_be(:ssh_key_created_2_day_ago) { create(:personal_key, user: user, created_at: 2.days.ago.to_date) }
          let_it_be(:ssh_key_created_3_day_ago) { create(:personal_key, user: user, created_at: 3.days.ago.to_date) }

          it "returns keys filtered with created_before the params value" do
            params[:created_before] = 2.days.ago.to_date

            get_request

            expect(response).to have_gitlab_http_status(:ok)
            expect_paginated_array_response([ssh_key_created_2_day_ago.id, ssh_key_created_3_day_ago.id])
            expect(json_response.count).to eq(2)
          end

          it "returns keys filtered with created_after the params value" do
            params[:created_after] = 2.days.ago.to_date

            get_request

            expect(response).to have_gitlab_http_status(:ok)
            expect_paginated_array_response([ssh_key_created_1_day_ago.id, ssh_key_created_2_day_ago.id])
            expect(json_response.count).to eq(2)
          end
        end

        context 'when expires_at date filters' do
          let_it_be(:ssh_key_expiring_in_1_day) do
            create(:personal_key, user: user, expires_at: 1.day.from_now.to_date)
          end

          let_it_be(:ssh_key_expiring_in_2_day) do
            create(:personal_key, user: user, expires_at: 2.days.from_now.to_date)
          end

          let_it_be(:ssh_key_expiring_in_3_day) do
            create(:personal_key, user: user, expires_at: 3.days.from_now.to_date)
          end

          it "returns keys filtered with expires_before the params value" do
            params[:expires_before] = 2.days.from_now.to_date

            get_request

            expect(response).to have_gitlab_http_status(status)
            expect_paginated_array_response([ssh_key_expiring_in_1_day.id, ssh_key_expiring_in_2_day.id])
            expect(json_response.count).to eq(2)
          end

          it "returns keys filtered with expires_after the params value" do
            params[:expires_after] = 2.days.from_now.to_date

            get_request

            expect(response).to have_gitlab_http_status(status)
            expect_paginated_array_response([ssh_key_expiring_in_2_day.id, ssh_key_expiring_in_3_day.id])
            expect(json_response.count).to eq(2)
          end
        end
      end
    end
  end
end
