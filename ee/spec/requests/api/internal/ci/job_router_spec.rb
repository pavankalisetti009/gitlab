# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Ci::JobRouter, feature_category: :continuous_integration do
  let_it_be(:runner) { create(:ci_runner, :instance) }
  let_it_be(:enabled_runner_controllers) { create_list(:ci_runner_controller, 2, :enabled) }
  let_it_be(:dry_run_runner_controllers) { create_list(:ci_runner_controller, 2, :dry_run) }
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

  describe 'GET /internal/ci/agents/runnerc/info' do
    subject(:request) { get api('/internal/ci/agents/runnerc/info'), headers: headers.reverse_merge(kas_headers) }

    context 'when not authenticated' do
      let(:headers) { { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => '' } }

      it 'returns 401' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when no Gitlab-Agent-Api-Request header is sent' do
      let(:headers) { {} }

      it 'returns 401' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when Gitlab-Agent-Api-Request header is for non-existent agent' do
      let(:headers) { { Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => 'NONEXISTENT' } }

      it 'returns 401' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when a runner controller is found' do
      let!(:runner_controller_token) { create(:ci_runner_controller_token) }

      let(:runner_controller) { runner_controller_token.runner_controller }
      let(:headers) { { Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => runner_controller_token.token } }

      it 'returns expected data' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(json_response).to eq('agent_id' => runner_controller.id)
      end
    end
  end

  describe 'GET /internal/ci/job_router/runner_controllers/job_admission' do
    subject(:perform_request) { get api('/internal/ci/job_router/runner_controllers/job_admission'), headers: headers }

    shared_examples 'returns active runner controllers with state' do
      it 'returns 200 with active runner controllers (enabled and dry_run) including state' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)

        expected_controllers = (enabled_runner_controllers + dry_run_runner_controllers).map do |c|
          { 'id' => c.id, 'state' => c.state }
        end

        expect(json_response['runner_controllers']).to match_array(expected_controllers)
      end
    end

    context 'when authenticated' do
      it_behaves_like 'returns active runner controllers with state'

      context 'when no active runner controllers exist' do
        before do
          Ci::RunnerController.active.delete_all
        end

        specify { expect(Ci::RunnerController.disabled).not_to be_empty }

        it 'returns empty array' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq('runner_controllers' => [])
        end
      end

      context 'when only enabled controllers exist' do
        before do
          Ci::RunnerController.delete_all
        end

        let!(:enabled_only) { create_list(:ci_runner_controller, 2, :enabled) }

        it 'returns only enabled controllers' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['runner_controllers']).to match_array(
            enabled_only.map { |c| { 'id' => c.id, 'state' => 'enabled' } }
          )
        end
      end

      context 'when only dry_run controllers exist' do
        before do
          Ci::RunnerController.delete_all
        end

        let!(:dry_run_only) { create_list(:ci_runner_controller, 2, :dry_run) }

        it 'returns only dry_run controllers' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['runner_controllers']).to match_array(
            dry_run_only.map { |c| { 'id' => c.id, 'state' => 'dry_run' } }
          )
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

        it_behaves_like 'returns active runner controllers with state'

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

        it_behaves_like 'returns active runner controllers with state'

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

        it_behaves_like 'returns active runner controllers with state'

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

  describe 'PUT /internal/ci/job_router/jobs/:id' do
    let_it_be(:project) { create(:project) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
    let_it_be(:job) { create(:ci_build, :running, pipeline: pipeline, project: project) }

    let(:job_headers) { kas_headers.merge(API::Ci::Helpers::Runner::JOB_TOKEN_HEADER => job.token) }
    let(:params) { { token: job.token, state: 'failed' } }

    subject(:perform_request) do
      put api("/internal/ci/job_router/jobs/#{job.id}"), params: params, headers: job_headers
    end

    context 'when authenticated' do
      let(:params) { { token: job.token } }

      context 'with valid parameters' do
        context 'when failing with job_router_failure' do
          let(:params) { super().merge(state: 'failed', failure_reason: 'job_router_failure') }

          it 'updates the job state' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(job.reload).to be_failed
            expect(job.failure_reason).to eq('job_router_failure')
            expect(job.job_messages).to be_empty
          end

          it 'returns job status header' do
            perform_request

            expect(response.headers['Job-Status']).to eq('failed')
          end

          it 'returns status code in body' do
            perform_request

            expect(response.body).to eq('"200"')
          end
        end

        context 'when failing with job_router_failure and custom message' do
          let(:params) do
            super().merge(
              state: 'failed',
              failure_reason: 'job_router_failure',
              failure_message: 'No available executors'
            )
          end

          it 'updates the job state and creates job message' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(job.reload).to be_failed
            expect(job.failure_reason).to eq('job_router_failure')
            expect(job.job_messages.count).to eq(1)
            expect(job.job_messages.first.content).to eq('No available executors')
          end
        end

        context 'when failing without failure_reason' do
          let(:params) { super().merge(state: 'failed') }

          it 'updates the job state with default failure reason' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(job.reload).to be_failed
            expect(job.job_messages).to be_empty
          end
        end
      end

      context 'with invalid parameters' do
        context 'when providing failure_message without job_router_failure' do
          let(:params) do
            super().merge(
              state: 'failed',
              failure_reason: 'script_failure',
              failure_message: 'This should not be allowed'
            )
          end

          it 'returns 400 bad request' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when providing invalid state' do
          let(:params) { super().merge(state: 'success') }

          it 'returns 400 bad request' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when providing invalid failure_reason' do
          let(:params) { super().merge(state: 'failed', failure_reason: 'script_failure') }

          it 'returns 400 bad request' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end
    end

    context 'when not authenticated' do
      context 'without KAS authentication' do
        let(:job_headers) { super().except(Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER) }

        it 'returns 401' do
          perform_request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'without job token' do
        let(:job_headers) { kas_headers }
        let(:params) { super().except(:token) }

        it 'returns 403' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with invalid job token' do
        let(:job_headers) { kas_headers.merge(API::Ci::Helpers::Runner::JOB_TOKEN_HEADER => 'invalid') }
        let(:params) { super().merge(token: 'invalid') }

        it 'returns 403' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with mismatched job id and token' do
        let_it_be(:other_job) { create(:ci_build, :running, pipeline: pipeline, project: project) }
        let(:job_headers) { kas_headers.merge(API::Ci::Helpers::Runner::JOB_TOKEN_HEADER => other_job.token) }
        let(:params) { super().merge(token: other_job.token) }

        it 'returns 403' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when rate limited' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it 'returns 429' do
        perform_request

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'with metrics and tracking' do
      let(:params) { super().merge(failure_reason: 'job_router_failure') }

      it 'adds update_build metric event' do
        expect(Gitlab::Metrics).to receive(:add_event).with(:update_build)

        perform_request
      end
    end
  end
end
