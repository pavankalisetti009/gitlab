# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Ai::XRay::Scan, feature_category: :code_suggestions do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:sub_namespace) { create(:group, parent: namespace) }
  let_it_be(:user) { create(:user) }
  let_it_be(:job) { create(:ci_build, :running, namespace: namespace, user: user) }
  let_it_be(:sub_job) { create(:ci_build, :running, namespace: sub_namespace, user: user) }
  let_it_be(:cloud_connector_service) { CloudConnector::BaseAvailableServiceData.new(:code_suggestions, nil, nil) }

  let(:duo_pro_purchased) { true }
  let(:ai_gateway_headers) { { 'ai-gateway-header' => 'value' } }
  let(:ai_gateway_token) { 'ai gateway token' }
  let(:gitlab_team_member) { false }
  let(:headers) { {} }
  let(:namespace_workhorse_headers) { {} }

  before do
    allow(::Gitlab::AiGateway).to receive(:headers)
      .with(user: user, service: cloud_connector_service, agent: anything)
      .and_return(ai_gateway_headers)
    allow(CloudConnector::AvailableServices).to receive(:find_by_name)
      .with(:code_suggestions)
      .and_return(cloud_connector_service)
    allow(cloud_connector_service).to receive(:purchased?).with(namespace).and_return(duo_pro_purchased)
    allow(cloud_connector_service).to receive(:access_token).with(namespace).and_return(ai_gateway_token)
  end

  describe 'POST /internal/jobs/:id/x_ray/scan' do
    let(:params) do
      {
        token: job.token,
        prompt_components: [{ payload: "test" }]
      }
    end

    let(:api_url) { "/internal/jobs/#{job.id}/x_ray/scan" }
    let(:enabled_by_namespace_ids) { [] }
    let(:enablement_type) { '' }

    subject(:post_api) do
      post api(api_url), params: params, headers: headers
    end

    context 'when job token is missing' do
      let(:params) do
        {
          prompt_components: [{ payload: "test" }]
        }
      end

      it 'returns Forbidden status' do
        post_api

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    shared_examples 'successful send request via workhorse' do
      let(:endpoint) { 'https://cloud.gitlab.com/ai/v1/x-ray/libraries' }

      shared_examples 'sends request to the X-Ray libraries' do
        it 'sends requests to the X-Ray libraries AI Gateway endpoint', :aggregate_failures do
          expected_body = params.except(:token)

          expect(Gitlab::Workhorse).to receive(:send_url).with(
            endpoint,
            body: expected_body.to_json,
            method: "POST",
            headers: namespace_workhorse_headers.merge("ai-gateway-header" => ["value"])
          )

          post_api

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      include_examples 'sends request to the X-Ray libraries'
    end

    context 'when on self-managed', :with_cloud_connector do
      context 'without code suggestion license feature' do
        before do
          stub_licensed_features(code_suggestions: false)
        end

        it 'returns NOT_FOUND status' do
          post_api

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with code suggestion license feature' do
        before do
          stub_licensed_features(code_suggestions: true)
        end

        context 'without Duo Pro add-on' do
          let(:duo_pro_purchased) { false }

          it 'responds with unauthorized' do
            post_api

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end

        context 'with Duo Pro add-on' do
          context 'when cloud connector access token is missing' do
            let(:ai_gateway_token) { nil }

            it 'returns UNAUTHORIZED status' do
              post_api

              expect(response).to have_gitlab_http_status(:unauthorized)
            end
          end

          context 'when cloud connector access token is valid' do
            it_behaves_like 'successful send request via workhorse'
          end
        end
      end
    end

    context 'when on Gitlab.com instance', :saas do
      let(:enabled_by_namespace_ids) { [namespace.id] }
      let(:enablement_type) { 'add_on' }
      let(:namespace_workhorse_headers) do
        {
          "X-Gitlab-Saas-Namespace-Ids" => [namespace.id.to_s]
        }
      end

      it_behaves_like 'successful send request via workhorse'

      it_behaves_like 'rate limited endpoint', rate_limit_key: :code_suggestions_x_ray_scan do
        def request
          post api(api_url), params: params, headers: headers
        end
      end

      context 'without Duo Pro add-on' do
        let(:duo_pro_purchased) { false }

        it 'responds with unauthorized' do
          post_api

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'POST /internal/jobs/:id/x_ray/dependencies' do
    let(:current_job) { job }
    let(:token) { current_job.token }
    let(:api_url) { "/internal/jobs/#{current_job.id}/x_ray/dependencies" }
    let(:params) do
      {
        token: token,
        language: 'Ruby',
        dependencies: %w[rails rspec-rails pry-rails]
      }
    end

    subject(:post_api) do
      post api(api_url), params: params, headers: headers
    end

    shared_examples 'successful request' do
      it 'responds with success' do
        post_api

        expect(response).to have_gitlab_http_status(:accepted)
      end

      it 'creates an X-Ray report' do
        post_api

        report = Projects::XrayReport.where(project: current_job.project, lang: params[:language]).last!

        expect(report.payload['libs']).to eq(params[:dependencies].map { |name| { 'name' => name } })
      end
    end

    context 'when job token is missing' do
      let(:token) { '' }

      it 'responds with forbidden' do
        post_api

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when on self-managed', :with_cloud_connector do
      context 'without code suggestion license feature' do
        before do
          stub_licensed_features(code_suggestions: false)
        end

        it 'responds with not found' do
          post_api

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with code suggestions license feature' do
        before do
          stub_licensed_features(code_suggestions: true)
        end

        context 'without Duo Pro add-on' do
          let(:duo_pro_purchased) { false }

          it 'responds with unauthorized' do
            post_api

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end

        context 'with Duo Pro add-on' do
          it_behaves_like 'successful request'
        end
      end
    end

    context 'when on Gitlab.com instance', :saas do
      it_behaves_like 'successful request'

      it_behaves_like 'rate limited endpoint', rate_limit_key: :code_suggestions_x_ray_dependencies do
        def request
          post api(api_url), params: params, headers: headers
        end
      end

      context 'when Xray::StoreDependenciesService responds with error' do
        before do
          store_service = instance_double(
            ::CodeSuggestions::Xray::StoreDependenciesService,
            execute: ServiceResponse.error(message: 'some validation error message')
          )
          allow(::CodeSuggestions::Xray::StoreDependenciesService).to receive(:new).and_return(store_service)
        end

        it 'responds with error', :aggregate_failures do
          post_api

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq({ 'message' => 'some validation error message' })
        end
      end

      context 'when language param is missing' do
        let(:params) do
          {
            token: token,
            dependencies: %w[rails rspec-rails pry-rails]
          }
        end

        it 'responds with error', :aggregate_failures do
          post_api

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq({ 'error' => 'language is missing, language does not have a valid value' })
        end
      end
    end
  end
end
