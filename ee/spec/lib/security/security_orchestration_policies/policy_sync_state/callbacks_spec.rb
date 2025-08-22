# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicySyncState::Callbacks, :clean_gitlab_redis_shared_state, feature_category: :security_policy_management do
  include described_class

  include_context 'with policy sync state'

  let(:merge_request_id) { 1 }
  let(:project_id) { 1 }

  describe '#clear_policy_sync_state' do
    specify do
      expect_next_instance_of(Security::SecurityOrchestrationPolicies::PolicySyncState::State,
        policy_configuration_id) do |state|
        expect(state).to receive(:clear)
      end

      clear_policy_sync_state(policy_configuration_id)
    end
  end

  describe '#append_projects_to_sync' do
    specify do
      expect_next_instance_of(Security::SecurityOrchestrationPolicies::PolicySyncState::State,
        policy_configuration_id) do |state|
        expect(state).to receive(:append_projects).with([project_id])
      end

      append_projects_to_sync(policy_configuration_id, [project_id])
    end
  end

  describe '#finish_project_policy_sync' do
    specify do
      expect_next_instance_of(Security::SecurityOrchestrationPolicies::PolicySyncState::State,
        policy_configuration_id) do |state|
        expect(state).to receive(:finish_project).with(project_id)
      end

      finish_project_policy_sync(project_id)
    end
  end

  describe '#fail_project_policy_sync' do
    specify do
      expect_next_instance_of(Security::SecurityOrchestrationPolicies::PolicySyncState::State,
        policy_configuration_id) do |state|
        expect(state).to receive(:fail_project).with(project_id)
      end

      fail_project_policy_sync(project_id)
    end
  end

  describe '#start_merge_request_policy_sync' do
    specify do
      expect_next_instance_of(Security::SecurityOrchestrationPolicies::PolicySyncState::State,
        policy_configuration_id) do |state|
        expect(state).to receive(:start_merge_request).with(merge_request_id)
      end

      start_merge_request_policy_sync(merge_request_id)
    end
  end

  describe '#start_merge_request_worker_policy_sync' do
    specify do
      expect_next_instance_of(Security::SecurityOrchestrationPolicies::PolicySyncState::State,
        policy_configuration_id) do |state|
        expect(state).to receive(:start_merge_request_worker).with(merge_request_id)
      end

      start_merge_request_worker_policy_sync(merge_request_id)
    end
  end

  describe '#finish_merge_request_worker_policy_sync' do
    specify do
      expect_next_instance_of(Security::SecurityOrchestrationPolicies::PolicySyncState::State,
        policy_configuration_id) do |state|
        expect(state).to receive(:finish_merge_request_worker).with(merge_request_id)
      end

      finish_merge_request_worker_policy_sync(merge_request_id)
    end
  end
end
