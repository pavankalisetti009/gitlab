# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::AuditLog, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:read_project_secret_log_json) do
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

  let(:create_project_secret_log_json) do
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
        "operation" => "create",
        "path" => "user_#{user.id}/project_#{project.id}/secrets/kv/data/explicit/new_secret",
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:delete_project_secret_log_json) do
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
        "operation" => "delete",
        "path" => "user_#{user.id}/project_#{project.id}/secrets/kv/metadata/explicit/deleted_secret",
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_project_secret_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "update",
        "path" => "user_#{user.id}/project_#{project.id}/secrets/kv/data/explicit/my_test_secret",
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_project_secret_request_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "request",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "update",
        "path" => "user_#{user.id}/project_#{project.id}/secrets/kv/data/explicit/my_test_secret",
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:unknown_event_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default"]
      },
      "request" => {
        "operation" => "list",
        "path" => "sys/auth",
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:invalid_json) { "invalid json content" }

  before_all do
    project.add_owner(user)
  end

  describe '#initialize' do
    it 'sets raw_audit_log_json and initializes attributes' do
      audit_log = described_class.new(update_project_secret_log_json)

      expect(audit_log.raw_audit_log_json).to eq(update_project_secret_log_json)
      expect(audit_log.project).to eq(project)
      expect(audit_log.event_type).to eq(:secrets_manager_update_project_secret)
      expect(audit_log.author).to eq(user)
      expect(audit_log.ip_address).to eq("172.16.123.1")
    end

    it 'handles invalid JSON gracefully' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(JSON::ParserError))

      audit_log = described_class.new(invalid_json)

      expect(audit_log.raw_audit_log_json).to eq(invalid_json)
    end
  end

  describe '#log!' do
    context 'when audit should be logged' do
      it 'calls Gitlab::Audit::Auditor.audit with correct context' do
        audit_log = described_class.new(update_project_secret_log_json)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: :secrets_manager_update_project_secret,
            author: user,
            scope: project,
            target: project,
            message: "Updated project secret",
            ip_address: "172.16.123.1",
            additional_details: { raw_audit_log_json: update_project_secret_log_json },
            target_details: "Project: #{project.full_path}"
          )
        ).and_call_original

        expect(audit_log.log!).to be_truthy
      end
    end

    context 'when runtime error occurs during logging' do
      it 'tracks the exception and returns false' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(ActiveRecord::RecordNotFound)
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(ActiveRecord::RecordNotFound))

        audit_log = described_class.new(update_project_secret_log_json)

        expect(audit_log.log!).to be_falsey
      end
    end

    context 'when audit should not be logged' do
      it 'does not call Gitlab::Audit::Auditor.audit for request logs' do
        audit_log = described_class.new(update_project_secret_request_log_json)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit_log.log!
      end

      it 'does not call Gitlab::Audit::Auditor.audit for unknown events' do
        audit_log = described_class.new(unknown_event_log_json)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit_log.log!
      end
    end
  end

  describe 'project secret operations' do
    using RSpec::Parameterized::TableSyntax

    where(:operation, :log_json_method, :expected_event_type, :expected_message) do
      # rubocop:disable Layout/LineLength -- Test Matrix table is too long
      'read'   | :read_project_secret_log_json    | :secrets_manager_read_project_secret   | "Read project secret in CI Pipeline Job"
      'create' | :create_project_secret_log_json  | :secrets_manager_create_project_secret | "Created project secret"
      'update' | :update_project_secret_log_json  | :secrets_manager_update_project_secret | "Updated project secret"
      'delete' | :delete_project_secret_log_json  | :secrets_manager_delete_project_secret | "Deleted project secret"
      # rubocop:enable Layout/LineLength -- Test Matrix table is too long
    end

    with_them do
      let(:audit_log) { described_class.new(public_send(log_json_method)) }

      describe 'audit event attributes' do
        it 'returns correct event type' do
          expect(audit_log.event_type).to eq(expected_event_type)
        end

        it 'returns correct message' do
          expect(audit_log.message).to eq(expected_message)
        end

        it 'extracts correct author' do
          expect(audit_log.author).to eq(user)
        end

        it 'extracts correct project' do
          expect(audit_log.project).to eq(project)
        end
      end
    end
  end
end
