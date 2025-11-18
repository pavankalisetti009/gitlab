# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Mcp::Base, feature_category: :mcp_server do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }

  describe 'POST /mcp' do
    context 'when gitlab.com', :saas do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, developers: user) }

      where(:group_experiment_features, :group_duo_features, :instance_ai_enabled, :duo_features_enabled,
        :expected_status) do
        true  | true  | true  | true  | :ok
        true  | true  | false | true  | :ok
        true  | true  | true  | false | :ok # instance setting ignored on SaaS
        true  | true  | false | false | :ok # instance setting ignored on SaaS
        false | true  | true  | true  | :not_found
        true  | false | true  | true  | :not_found
        false | false | true  | true  | :not_found
        false | true  | false | true  | :not_found
        true  | false | false | true  | :not_found
        false | false | false | true  | :not_found
        false | true  | true  | false | :not_found
        true  | false | true  | false | :not_found
        false | false | true  | false | :not_found
        false | true  | false | false | :not_found
        true  | false | false | false | :not_found
        false | false | false | false | :not_found
      end

      with_them do
        before do
          stub_saas_features(gitlab_duo_saas_only: true)
          stub_application_setting(
            instance_level_ai_beta_features_enabled: instance_ai_enabled,
            duo_features_enabled: duo_features_enabled
          )
          group.namespace_settings.reload.update!(
            experiment_features_enabled: group_experiment_features,
            duo_features_enabled: group_duo_features
          )
        end

        it 'behaves according to access control rules' do
          post api('/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'initialize', id: '1' }

          expect(response).to have_gitlab_http_status(expected_status)
        end
      end
    end

    context 'when not gitlab.com' do
      let_it_be(:group) { create(:group, developers: user) }

      where(:group_experiment_features, :group_duo_features, :instance_ai_enabled, :duo_features_enabled,
        :expected_status) do
        true  | true  | true  | true  | :ok
        false | true  | true  | true  | :ok # group setting ignored on non-SaaS
        true  | false | true  | true  | :ok # group setting ignored on non-SaaS
        false | false | true  | true  | :ok
        true  | true  | false | true  | :not_found
        false | true  | false | true  | :not_found
        true  | false | false | true  | :not_found
        false | false | false | true  | :not_found
        true  | true  | true  | false | :not_found
        false | true  | true  | false | :not_found
        true  | false | true  | false | :not_found
        false | false | true  | false | :not_found
        true  | true  | false | false | :not_found
        false | true  | false | false | :not_found
        true  | false | false | false | :not_found
        false | false | false | false | :not_found
      end

      with_them do
        before do
          stub_application_setting(
            instance_level_ai_beta_features_enabled: instance_ai_enabled,
            duo_features_enabled: duo_features_enabled
          )
          group.namespace_settings.reload.update!(
            experiment_features_enabled: group_experiment_features,
            duo_features_enabled: group_duo_features
          )
        end

        it 'behaves according to access control rules' do
          post api('/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'initialize', id: '1' }

          expect(response).to have_gitlab_http_status(expected_status)
        end
      end
    end
  end
end
