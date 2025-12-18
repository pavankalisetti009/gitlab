# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Ci::JobRouter, feature_category: :continuous_integration do
  let_it_be(:runner) { create(:ci_runner, :instance) }
  let_it_be(:runner_controllers) { create_list(:ci_runner_controller, 3, :enabled) }
  let_it_be(:disabled_runner_controllers) { create_list(:ci_runner_controller, 2) }

  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }
  let(:jwt_token) do
    JWT.encode(
      { 'iss' => Gitlab::Kas::JWT_ISSUER, 'aud' => Gitlab::Kas::JWT_AUDIENCE },
      jwt_secret,
      'HS256'
    )
  end

  let(:kas_headers) { { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => jwt_token } }
  let(:runner_headers) { { API::Ci::Helpers::Runner::RUNNER_TOKEN_HEADER => runner.token } }
  let(:headers) { kas_headers.merge(runner_headers) }

  before do
    allow(Gitlab::Kas).to receive_messages(enabled?: true, secret: jwt_secret)
  end

  describe 'GET /internal/ci/job_router/runner_controllers/job_admission' do
    subject(:perform_request) { get api('/internal/ci/job_router/runner_controllers/job_admission'), headers: headers }

    shared_examples 'returns enabled runner controller ids' do
      it 'returns 200 with enabled runner controller ids' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq(
          'runner_controllers' => runner_controllers.map { |c| { 'id' => c.id } }
        )
      end
    end

    context 'when authenticated' do
      it_behaves_like 'returns enabled runner controller ids'

      context 'when no runner controllers exist' do
        let_it_be(:runner_controllers) { [] }

        before do
          Ci::RunnerController.delete_all
        end

        it 'returns empty array' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({ 'runner_controllers' => [] })
        end
      end
    end

    context 'when not authenticated' do
      context 'without KAS authentication' do
        let(:headers) { runner_headers }

        it 'returns 401' do
          perform_request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'without runner authentication' do
        let(:headers) { kas_headers }

        it 'returns 403' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with invalid runner token' do
        let(:runner_headers) { { API::Ci::Helpers::Runner::RUNNER_TOKEN_HEADER => 'invalid' } }

        it 'returns 403' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when feature flags are disabled' do
      context 'when Gitlab::Kas is disabled' do
        before do
          allow(Gitlab::Kas).to receive(:enabled?).and_return(false)
        end

        it 'returns 501' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_implemented)
          expect(json_response['message']).to eq('Job Router is not available. Please contact your administrator.')
        end
      end

      context 'when job_router and job_router_instance_runners feature flags are disabled' do
        before do
          stub_feature_flags(job_router: false, job_router_instance_runners: false)
        end

        it 'returns 501' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_implemented)
          expect(json_response['message']).to eq('Job Router is not available. Please contact your administrator.')
        end
      end

      context 'when job_router_admission_control feature flag is disabled' do
        before do
          stub_feature_flags(job_router_admission_control: false)
        end

        it 'returns 501' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_implemented)
          expect(json_response['message']).to eq(
            'Admission Control is not available. Please contact your administrator.'
          )
        end
      end

      context 'when job_router, job_router_instance_runners and job_router_admission_control FFs are disabled' do
        before do
          stub_feature_flags(
            job_router: false,
            job_router_instance_runners: false,
            job_router_admission_control: false
          )
        end

        it 'returns 501 for job_router first' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_implemented)
          expect(json_response['message']).to eq('Job Router is not available. Please contact your administrator.')
        end
      end
    end

    context 'with different runner types' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }

      context 'with instance runner' do
        let_it_be(:runner) { create(:ci_runner, :instance) }

        it_behaves_like 'returns enabled runner controller ids'

        context 'when job_router and job_router_instance_runners feature flags are disabled' do
          before do
            stub_feature_flags(job_router_instance_runners: false, job_router: false)
          end

          it 'returns 501' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_implemented)
          end
        end
      end

      context 'with group runner' do
        let_it_be(:runner) { create(:ci_runner, :group, groups: [group]) }

        it_behaves_like 'returns enabled runner controller ids'

        context 'when job_router is disabled for the group' do
          before do
            stub_feature_flags(job_router: false)
          end

          it 'returns 501' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_implemented)
          end
        end
      end

      context 'with project runner' do
        let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }

        it_behaves_like 'returns enabled runner controller ids'

        context 'when job_router is disabled for the project' do
          before do
            stub_feature_flags(job_router: false)
          end

          it 'returns 501' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_implemented)
          end
        end
      end
    end
  end
end
