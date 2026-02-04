# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::AuditLog, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }

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
        "path" => "secrets/kv/data/explicit/my_test_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}/" },
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
        "path" => "secrets/kv/data/explicit/new_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
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
        "path" => "secrets/kv/metadata/explicit/deleted_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
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
        "path" => "secrets/kv/data/explicit/my_test_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
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
        "path" => "secrets/kv/data/explicit/my_test_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:read_group_secret_log_json) do
    {
      "time" => "2026-01-12T15:10:16.613438Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}", "users/roles/50"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESC3ZDGGZSSD1S1YXESC802",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "read",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORDDS",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:create_group_secret_log_json) do
    {
      "time" => "2026-01-12T14:51:57.787927Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}", "users/roles/50"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESB2EA5HPDQHBHVQQ0ZZ93D",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "create",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORD",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:delete_group_secret_log_json) do
    {
      "time" => "2026-01-12T14:52:00.123456Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESB2EA5HPDQHBHVQQ0ZZ93D",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "delete",
        "path" => "secrets/kv/metadata/explicit/DATABASE_PASSWORD",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_group_secret_log_json) do
    {
      "time" => "2026-01-12T15:10:27.457384Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}", "users/roles/50"],
        "metadata" => {
          "correlation_id" => "01KESC49YJ5HFYX8S68H2EF79T",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "update",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORDDS",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_group_secret_request_log_json) do
    {
      "time" => "2026-01-12T15:10:27.457184Z",
      "type" => "request",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{group.id}"],
        "metadata" => {
          "correlation_id" => "01KESC49YJ5HFYX8S68H2EF79T",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "update",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORDDS",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
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
  let(:non_existing_project_id) { non_existing_record_id }
  let(:non_existing_group_id) { non_existing_record_id }

  before_all do
    project.add_owner(user)
    group.add_owner(user)
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

  describe '#target_details' do
    it 'includes the project path for project secret events' do
      audit_log = described_class.new(update_project_secret_log_json)

      expect(audit_log.target_details).to eq("Project: #{project.full_path}")
    end

    it 'includes the group path for group secret events' do
      audit_log = described_class.new(read_group_secret_log_json)

      expect(audit_log.target_details).to eq("Group: #{group.full_path}")
    end

    it 'returns an empty project path when the project is missing' do
      payload = Gitlab::Json.safe_parse(read_project_secret_log_json)
      payload["request"]["namespace"]["path"] = "user_#{user.id}/project_#{non_existing_project_id}/"
      payload["auth"]["metadata"]["project_id"] = non_existing_project_id.to_s
      audit_log = described_class.new(payload.to_json)

      expect(audit_log.target_details).to eq("Project: ")
    end

    it 'returns an empty group path when the group is missing' do
      payload = Gitlab::Json.safe_parse(read_group_secret_log_json)
      payload["request"]["namespace"]["path"] = "group_#{non_existing_group_id}/group_#{non_existing_group_id}/"
      payload["auth"]["metadata"]["group_id"] = non_existing_group_id.to_s
      audit_log = described_class.new(payload.to_json)

      expect(audit_log.target_details).to eq("Group: ")
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
      it 'does not call Gitlab::Audit::Auditor.audit for project secret request logs' do
        audit_log = described_class.new(update_project_secret_request_log_json)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit_log.log!
      end

      it 'does not call Gitlab::Audit::Auditor.audit for group secret request logs' do
        audit_log = described_class.new(update_group_secret_request_log_json)

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

  describe 'group secret operations' do
    using RSpec::Parameterized::TableSyntax

    where(:operation, :log_json_method, :expected_event_type, :expected_message) do
      # rubocop:disable Layout/LineLength -- Test Matrix table is too long
      'read'   | :read_group_secret_log_json    | :secrets_manager_read_group_secret   | "Read group secret in CI Pipeline Job"
      'create' | :create_group_secret_log_json  | :secrets_manager_create_group_secret | "Created group secret"
      'update' | :update_group_secret_log_json  | :secrets_manager_update_group_secret | "Updated group secret"
      'delete' | :delete_group_secret_log_json  | :secrets_manager_delete_group_secret | "Deleted group secret"
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

        it 'extracts correct group' do
          expect(audit_log.group).to eq(group)
        end
      end
    end
  end

  describe 'namespace path matching' do
    it 'sets group to nil when namespace path does not match group pattern' do
      audit_log = described_class.allocate
      allow(audit_log).to receive_messages(
        get_event_type: :secrets_manager_read_group_secret,
        namespace_path: "group_#{group.id}/invalid_path/"
      )
      audit_log.send(:initialize, read_group_secret_log_json)

      expect(audit_log.group).to be_nil
    end

    context 'when namespace path contains both project and group patterns' do
      let(:ambiguous_namespace_log_json) do
        {
          "time" => "2026-01-12T15:10:16.613438Z",
          "type" => "response",
          "auth" => {
            "policies" => ["default"],
            "metadata" => {
              "correlation_id" => "01KESC3ZDGGZSSD1S1YXESC802",
              "group_id" => group.id.to_s,
              "user_id" => user.id.to_s
            }
          },
          "request" => {
            "operation" => "read",
            "path" => "secrets/kv/data/explicit/DATABASE_PASSWORD",
            "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/project_999/" },
            "remote_address" => "172.16.123.1"
          },
          "response" => {
            "mount_type" => "kv"
          }
        }.to_json
      end

      it 'does not incorrectly match as project secret event' do
        audit_log = described_class.new(ambiguous_namespace_log_json)

        expect(audit_log.event_type).not_to eq(:secrets_manager_read_project_secret)
      end
    end
  end
end
