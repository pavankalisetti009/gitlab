# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::SecretsManager, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let(:sample_audit_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "entity_id" => "60792534-ee8a-bdc5-6416-005af4303ac4",
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "read",
        "path" => "user_#{user.id}/project_#{project.id}/secrets/kv/data/explicit/my_test_secret",
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:headers) do
    {
      'Gitlab-Openbao-Auth-Token' => 'test_token',
      'Content-Type' => 'application/json'
    }
  end

  before do
    openbao_config = Gitlab.config.openbao
    openbao_config['authentication_token_secret_file_path'] =
      Rails.root.join('ee/spec/fixtures/secrets_manager/gitlab_openbao_authentication_token_secret.txt')
    allow(Gitlab.config).to receive(:openbao).and_return(openbao_config)
  end

  describe 'POST /internal/secrets_manager/audit_logs' do
    it 'creates a new audit log entry' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(
          name: :secrets_manager_read_project_secret,
          message: "Read project secret in CI Pipeline Job",
          ip_address: "172.16.123.1"
        )
      ).and_call_original

      post api('/internal/secrets_manager/audit_logs'), params: sample_audit_log_json, headers: headers

      expect(response).to have_gitlab_http_status(:accepted)
    end

    context 'when authentication fails' do
      it 'returns unauthorized status' do
        headers = {
          'Gitlab-Openbao-Auth-Token' => 'invalid_token',
          'Content-Type' => 'application/json'
        }

        post api('/internal/secrets_manager/audit_logs'), params: sample_audit_log_json, headers: headers

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      context 'when authentication token is not readable' do
        it 'returns unauthorized status' do
          allow_next_instance_of(Pathname) do |path|
            allow(path).to receive(:realpath).and_raise(Errno::EACCES)
          end

          post api('/internal/secrets_manager/audit_logs'), params: sample_audit_log_json, headers: headers
          expect(response).to have_gitlab_http_status(:internal_server_error)
          expect(response.body).to include('Unable to fetch Openbao authentication token secret')
        end
      end
    end

    context 'when payload size exceeds limit' do
      it 'returns bad request status' do
        allow_next_instance_of(Grape::Request) do |request|
          allow(request).to receive(:content_length).and_return(1.megabyte + 1)
        end

        post api('/internal/secrets_manager/audit_logs'), params: sample_audit_log_json, headers: headers

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end
end
