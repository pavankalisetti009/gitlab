# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::API, feature_category: :system_access do
  include Auth::DpopTokenHelper

  describe 'logging', :aggregate_failures do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:user) { project.first_owner }

    context 'when the method is not allowed' do
      it 'logs the route and context metadata for the client' do
        expect(described_class::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
          expect(data.stringify_keys)
            .to include('correlation_id' => an_instance_of(String),
              'meta.remote_ip' => an_instance_of(String),
              'meta.client_id' => a_string_matching(%r{\Aip/.+}),
              'route' => '/api/scim/:version/groups/:group/Users/:id')

          expect(data.stringify_keys).not_to include('meta.caller_id', 'meta.user')
        end

        allow(Gitlab::Auth::GroupSaml::Config).to receive(:enabled?).and_return(true)

        process(:put, '/api/scim/v2/groups/1/Users/foo')

        expect(response).to have_gitlab_http_status(:method_not_allowed)
      end
    end
  end

  describe 'DPoP authentication' do
    shared_examples "checks for dpop token" do
      let(:dpop_proof) { generate_dpop_proof_for(user) }

      context 'with a missing DPoP token' do
        it 'returns 401' do
          get api(request_path, personal_access_token: personal_access_token)

          expect(json_response["error_description"]).to eq("DPoP validation error: DPoP header is missing")
          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'with a valid DPoP token' do
        it 'returns 200' do
          get(api(request_path, personal_access_token: personal_access_token), headers: { "dpop" => dpop_proof.proof })
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with a malformed DPoP token' do
        it 'returns 401' do
          get(api(request_path, personal_access_token: personal_access_token), headers: { "dpop" => 'invalid' })
          # rubocop:disable Layout/LineLength -- We need the entire error message
          expect(json_response["error_description"]).to eq("DPoP validation error: Malformed JWT, unable to decode. Not enough or too many segments")
          # rubocop:enable Layout/LineLength
          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end

    context 'when :dpop_authentication FF is enabled' do
      before do
        stub_feature_flags(dpop_authentication: true)
      end

      context 'when DPoP is disabled for the user' do
        let(:user) { create(:user) }

        context 'when endpoint is groups/manage' do
          let(:group) { create(:group) }
          let(:personal_access_token) { create(:personal_access_token, user: user, scopes: [:api]) }
          let(:request_path) { "/groups/#{group.id}/manage/personal_access_tokens" }

          before do
            group.add_owner(user)
          end

          it_behaves_like "checks for dpop token"

          context 'when feature flag manage_pat_by_group_owners_ready is set false' do
            before do
              stub_feature_flags(manage_pat_by_group_owners_ready: false)
            end

            it 'does not check for DPoP token' do
              get api('/groups')
              expect(response).to have_gitlab_http_status(:ok)
            end
          end
        end
      end
    end
  end
end
