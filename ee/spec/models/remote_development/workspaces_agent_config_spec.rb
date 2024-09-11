# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspacesAgentConfig, feature_category: :workspaces do
  let_it_be_with_reload(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
  let(:default_default_resources_per_workspace_container) { {} }
  let(:default_max_resources_per_workspace) { {} }
  let(:default_network_policy_egress) do
    [
      {
        allow: "0.0.0.0/0",
        except: [
          - "10.0.0.0/8",
          - "172.16.0.0/12",
          - "192.168.0.0/16"
        ]
      }.deep_stringify_keys
    ]
  end

  let(:default_max_hours_before_termination_default_value) { 24 }
  let(:max_hours_before_termination_limit_default_value) { 120 }
  let(:allow_privilege_escalation) { false }
  let(:use_kubernetes_user_namespaces) { false }
  let(:default_runtime_class) { "" }

  subject(:config) { agent.workspaces_agent_config }

  describe 'associations' do
    it { is_expected.to belong_to(:agent) }
    it { is_expected.to have_many(:workspaces) }

    context 'with associated workspaces' do
      let(:workspace_1) { create(:workspace, agent: agent) }
      let(:workspace_2) { create(:workspace, agent: agent) }

      it 'has correct associations from factory' do
        expect(config.reload.workspaces).to contain_exactly(workspace_1, workspace_2)
        expect(workspace_1.workspaces_agent_config).to eq(config)
      end
    end
  end

  describe 'validations' do
    context 'when config has an invalid dns_zone' do
      subject(:config) { build(:workspaces_agent_config, dns_zone: "invalid dns zone") }

      it 'prevents config from being created' do
        expect { config.save! }.to raise_error(
          ActiveRecord::RecordInvalid,
          "Validation failed: Dns zone contains invalid characters (valid characters: [a-z0-9\\-])"
        )
      end
    end

    it 'when network_policy_egress is not specified explicitly' do
      expect(config).to be_valid
      expect(config.network_policy_egress).to eq(default_network_policy_egress)
    end

    it 'when network_policy_egress is nil' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.network_policy_egress = nil
      expect(config).not_to be_valid
      expect(config.errors[:network_policy_egress]).to include(
        'must be a valid json schema',
        'must be an array'
      )
    end

    it 'when default_resources_per_workspace_container is not specified explicitly' do
      expect(config).to be_valid
      expect(config.default_resources_per_workspace_container).to eq(default_default_resources_per_workspace_container)
    end

    it 'when default_resources_per_workspace_container is nil' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.default_resources_per_workspace_container = nil
      expect(config).not_to be_valid
      expect(config.errors[:default_resources_per_workspace_container]).to include(
        'must be a valid json schema',
        'must be a hash'
      )
    end

    it 'when max_resources_per_workspace is not specified explicitly' do
      expect(config).to be_valid
      expect(config.max_resources_per_workspace).to eq(default_max_resources_per_workspace)
    end

    it 'when default_max_hours_before_termination is not specified explicitly' do
      expect(config).to be_valid
      expect(config.default_max_hours_before_termination).to eq(default_max_hours_before_termination_default_value)
    end

    it 'when max_hours_before_termination_limit is not specified explicitly' do
      expect(config).to be_valid
      expect(config.max_hours_before_termination_limit).to eq(max_hours_before_termination_limit_default_value)
    end

    it 'when default_resources_per_workspace_container is nil' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.max_resources_per_workspace = nil
      expect(config).not_to be_valid
      expect(config.errors[:max_resources_per_workspace]).to include(
        'must be a valid json schema',
        'must be a hash'
      )
    end

    it 'allows numerical values for workspaces_quota greater or equal to -1' do
      is_expected.to validate_numericality_of(:workspaces_quota).only_integer.is_greater_than_or_equal_to(-1)
    end

    it 'allows numerical values for workspaces_per_user_quota greater or equal to -1' do
      validate_numericality_of(:workspaces_per_user_quota).only_integer.is_greater_than_or_equal_to(-1)
    end

    it 'allows numerical values for max_hours_before_termination_limit greater or equal to' \
      'default_max_hours_before_termination and less than or equal to 8760' do
      is_expected.to validate_numericality_of(:max_hours_before_termination_limit)
        .only_integer
        .is_less_than_or_equal_to(8760)
        .is_greater_than_or_equal_to(default_max_hours_before_termination_default_value)
    end

    it 'allows numerical values for default_max_hours_before_termination greater or equal to 1' \
      'and less than or equal to max_hours_before_termination_limit' do
      is_expected.to validate_numericality_of(:default_max_hours_before_termination)
        .only_integer.is_less_than_or_equal_to(max_hours_before_termination_limit_default_value)
        .is_greater_than_or_equal_to(1)
    end

    context 'when config has allow_privilege_escalation set to true' do
      let(:allow_privilege_escalation) { true }

      subject(:config) { build(:workspaces_agent_config, allow_privilege_escalation: true) }

      it 'prevents config from being created' do
        expect { config.save! }.to raise_error(
          ActiveRecord::RecordInvalid,
          "Validation failed: Allow privilege escalation can be true only if " \
            "either use_kubernetes_user_namespaces is true or default_runtime_class is non-empty"
        )
      end

      context 'when use_kubernetes_user_namespaces is set to true' do
        let(:use_kubernetes_user_namespaces) { true }

        subject(:config) do
          build(
            :workspaces_agent_config,
            allow_privilege_escalation: allow_privilege_escalation,
            use_kubernetes_user_namespaces: use_kubernetes_user_namespaces
          )
        end

        it 'allows the config to be created' do
          expect(config).to be_valid
          expect(config.allow_privilege_escalation).to eq(allow_privilege_escalation)
          expect(config.use_kubernetes_user_namespaces).to eq(use_kubernetes_user_namespaces)
        end
      end

      context 'when default_runtime_class is set to non-empty value' do
        let(:default_runtime_class) { "test" }

        subject(:config) do
          build(
            :workspaces_agent_config,
            allow_privilege_escalation: allow_privilege_escalation,
            default_runtime_class: default_runtime_class
          )
        end

        it 'allows the config to be created' do
          expect(config).to be_valid
          expect(config.allow_privilege_escalation).to eq(true)
          expect(config.default_runtime_class).to eq(default_runtime_class)
        end
      end
    end
  end
end
