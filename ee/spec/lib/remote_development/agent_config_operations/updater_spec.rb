# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Can we have less?
RSpec.describe ::RemoteDevelopment::AgentConfigOperations::Updater, feature_category: :workspaces do
  include ResultMatchers

  let(:enabled) { true }
  let_it_be(:dns_zone) { 'my-awesome-domain.me' }
  let(:termination_limits_sets) { false }
  let(:default_unlimited_quota) { -1 }
  let(:saved_quota) { 5 }
  let(:quota) { 5 }
  let(:network_policy_present) { false }
  let(:default_network_policy_egress) do
    [{
      allow: "0.0.0.0/0",
      except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
    }]
  end

  let(:network_policy_egress) { default_network_policy_egress }
  let(:network_policy_enabled) { true }
  let(:network_policy_without_egress) do
    { enabled: network_policy_enabled }
  end

  let(:network_policy_with_egress) do
    {
      enabled: network_policy_enabled,
      egress: network_policy_egress
    }
  end

  let(:network_policy) { network_policy_without_egress }
  let(:gitlab_workspaces_proxy_present) { false }
  let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces' }
  let(:gitlab_workspaces_proxy) do
    { namespace: gitlab_workspaces_proxy_namespace }
  end

  let(:default_default_resources_per_workspace_container) { {} }
  let(:default_resources_per_workspace_container) { default_default_resources_per_workspace_container }
  let(:default_max_resources_per_workspace) { {} }
  let(:max_resources_per_workspace) { default_max_resources_per_workspace }
  let(:default_max_hours_before_termination) { 24 }
  let(:max_hours_before_termination_limit) { 120 }
  let(:allow_privilege_escalation) { false }
  let(:use_kubernetes_user_namespaces) { false }
  let(:default_runtime_class) { "" }
  let(:annotations) { {} }
  let(:labels) { {} }

  let_it_be(:agent, refind: true) { create(:cluster_agent) }

  let(:dns_zone_in_config) { dns_zone }

  let(:config) do
    remote_development_config = {
      'enabled' => enabled,
      'dns_zone' => dns_zone_in_config
    }
    remote_development_config['network_policy'] = network_policy if network_policy_present
    remote_development_config['gitlab_workspaces_proxy'] = gitlab_workspaces_proxy if gitlab_workspaces_proxy_present
    remote_development_config['default_resources_per_workspace_container'] = default_resources_per_workspace_container
    remote_development_config['max_resources_per_workspace'] = max_resources_per_workspace

    if termination_limits_sets
      remote_development_config['default_max_hours_before_termination'] = default_max_hours_before_termination
      remote_development_config['max_hours_before_termination_limit'] = max_hours_before_termination_limit
    end

    if quota
      remote_development_config['workspaces_quota'] = quota
      remote_development_config['workspaces_per_user_quota'] = quota
    end

    remote_development_config['allow_privilege_escalation'] = allow_privilege_escalation if allow_privilege_escalation
    remote_development_config['use_kubernetes_user_namespaces'] = use_kubernetes_user_namespaces
    remote_development_config['default_runtime_class'] = default_runtime_class
    remote_development_config['annotations'] = annotations
    remote_development_config['labels'] = labels

    {
      remote_development: HashWithIndifferentAccess.new(remote_development_config)
    }
  end

  let(:agent_config_setting_names) do
    [
      :default_max_hours_before_termination,
      :default_resources_per_workspace_container,
      :gitlab_workspaces_proxy_namespace,
      :max_hours_before_termination_limit,
      :max_resources_per_workspace,
      :network_policy_egress,
      :network_policy_enabled,
      :workspaces_per_user_quota,
      :workspaces_quota,
      :allow_privilege_escalation,
      :use_kubernetes_user_namespaces,
      :default_runtime_class,
      :annotations,
      :labels
    ]
  end

  let(:agent_config_setting_values) do
    {
      default_max_hours_before_termination: default_max_hours_before_termination,
      default_resources_per_workspace_container: default_default_resources_per_workspace_container,
      gitlab_workspaces_proxy_namespace: "gitlab-workspaces",
      max_hours_before_termination_limit: max_hours_before_termination_limit,
      max_resources_per_workspace: default_max_resources_per_workspace,
      network_policy_egress: default_network_policy_egress,
      network_policy_enabled: network_policy_enabled,
      workspaces_per_user_quota: default_unlimited_quota,
      workspaces_quota: default_unlimited_quota,
      allow_privilege_escalation: allow_privilege_escalation,
      use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
      default_runtime_class: default_runtime_class,
      annotations: annotations,
      labels: labels
    }
  end

  before do
    allow(RemoteDevelopment::Settings)
      .to receive(:get).with(agent_config_setting_names).and_return(agent_config_setting_values)
  end

  subject(:result) do
    described_class.update(agent: agent, config: config) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
  end

  context 'when config passed is empty' do
    let(:config) { {} }

    it "does not update and returns an ok Result containing a hash indicating update was skipped" do
      expect { result }.to not_change { RemoteDevelopment::WorkspacesAgentConfig.count }

      expect(result)
        .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound.new(
          { skipped_reason: :no_config_file_entry_found }
        ))
    end
  end

  context 'when config passed is not empty' do
    shared_examples 'successful update' do
      it 'creates a config record and returns an ok Result containing the agent config' do
        expect { result }.to change { RemoteDevelopment::WorkspacesAgentConfig.count }.by(expected_configs_created)

        config_instance = agent.reload.workspaces_agent_config
        expect(config_instance.enabled).to eq(enabled)
        expect(config_instance.project_id).to eq(agent.project_id)
        expect(config_instance.dns_zone).to eq(expected_dns_zone)
        expect(config_instance.network_policy_enabled).to eq(network_policy_enabled)
        expect(config_instance.network_policy_egress.map(&:deep_symbolize_keys)).to eq(network_policy_egress)
        expect(config_instance.gitlab_workspaces_proxy_namespace).to eq(gitlab_workspaces_proxy_namespace)
        expect(config_instance.default_resources_per_workspace_container.deep_symbolize_keys)
          .to eq(default_resources_per_workspace_container)
        expect(config_instance.max_resources_per_workspace.deep_symbolize_keys)
          .to eq(max_resources_per_workspace)
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(config_instance.workspaces_quota).to eq(saved_quota)
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(config_instance.workspaces_per_user_quota).to eq(saved_quota)
        expect(config_instance.default_max_hours_before_termination).to eq(default_max_hours_before_termination)
        expect(config_instance.max_hours_before_termination_limit).to eq(max_hours_before_termination_limit)
        expect(config_instance.allow_privilege_escalation).to eq(allow_privilege_escalation)
        expect(config_instance.use_kubernetes_user_namespaces).to eq(use_kubernetes_user_namespaces)
        expect(config_instance.default_runtime_class).to eq(default_runtime_class)
        expect(config_instance.annotations.deep_symbolize_keys).to eq(annotations)
        expect(config_instance.labels.deep_symbolize_keys).to eq(labels)

        expect(result)
          .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(
            { workspaces_agent_config: config_instance }
          ))

        expect(config_instance.workspaces.desired_state_not_terminated)
          .to all(have_attributes(force_include_all_resources: true))
      end
    end

    context 'when a config file is valid' do
      let(:expected_dns_zone) { dns_zone }
      let(:expected_configs_created) { 1 }

      context "without existing workspaces_agent_config" do
        it_behaves_like 'successful update'

        context 'when enabled is not present in the config passed' do
          let(:config) { { remote_development: { dns_zone: dns_zone } } }

          it 'creates a config record with a default context of enabled as false' do
            expect { result }.to change { RemoteDevelopment::WorkspacesAgentConfig.count }
            expect(result).to be_ok_result
            expect(agent.reload.workspaces_agent_config.enabled).to eq(false)
          end
        end

        context 'when network_policy key is present in the config passed' do
          let(:network_policy_present) { true }

          context 'when network_policy key is empty hash in the config passed' do
            let(:network_policy) { {} }

            it_behaves_like 'successful update'
          end

          context 'when network_policy.enabled is explicitly specified in the config passed' do
            let(:network_policy_enabled) { false }

            it_behaves_like 'successful update'
          end

          context 'when network_policy.egress is explicitly specified in the config passed' do
            let(:network_policy_egress) do
              [
                {
                  allow: "0.0.0.0/0",
                  except: %w[10.0.0.0/8]
                }
              ].freeze
            end

            let(:network_policy) { network_policy_with_egress }

            it_behaves_like 'successful update'
          end

          context 'when default and max_hours_before_termination are explicitly specified in the config passed' do
            let(:termination_limits_sets) { true }
            let(:default_max_hours_before_termination) { 20 }
            let(:max_hours_before_termination_limit) { 220 }

            it_behaves_like 'successful update'
          end
        end

        context 'when gitlab_workspaces_proxy is present in the config passed' do
          let(:gitlab_workspaces_proxy_present) { true }

          context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
            let(:gitlab_workspaces_proxy) { {} }

            it_behaves_like 'successful update'
          end

          context 'when gitlab_workspaces_proxy.namespace is explicitly specified in the config passed' do
            let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces-specified' }

            it_behaves_like 'successful update'
          end
        end

        context 'when default_resources_per_workspace_container is present in the config passed' do
          context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
            let(:default_resources_per_workspace_container) { {} }

            it_behaves_like 'successful update'
          end

          context 'when default_resources_per_workspace_container is explicitly specified in the config passed' do
            let(:default_resources_per_workspace_container) do
              { limits: { cpu: "500m", memory: "1Gi" }, requests: { cpu: "200m", memory: "0.5Gi" } }
            end

            it_behaves_like 'successful update'
          end
        end

        context 'when max_resources_per_workspace is present in the config passed' do
          context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
            let(:max_resources_per_workspace) { {} }

            it_behaves_like 'successful update'
          end

          context 'when max_resources_per_workspace is explicitly specified in the config passed' do
            let(:max_resources_per_workspace) do
              { limits: { cpu: "500m", memory: "1Gi" }, requests: { cpu: "200m", memory: "0.5Gi" } }
            end

            it_behaves_like 'successful update'
          end
        end

        context 'when workspace quotas are not explicitly specified in the config passed' do
          let(:quota) { nil }
          let(:saved_quota) { -1 }

          it_behaves_like 'successful update'
        end
      end

      context 'when allow_privilege_escalation is explicitly specified in the config passed' do
        let(:allow_privilege_escalation) { true }

        context 'when use_kubernetes_user_namespaces is explicitly specified in the config passed' do
          let(:use_kubernetes_user_namespaces) { true }

          it_behaves_like 'successful update'
        end

        context 'when default_runtime_class is explicitly specified in the config passed' do
          let(:default_runtime_class) { "test" }

          it_behaves_like 'successful update'
        end
      end

      context 'when use_kubernetes_user_namespaces is explicitly specified in the config passed' do
        let(:use_kubernetes_user_namespaces) { true }

        it_behaves_like 'successful update'
      end

      context 'when default_runtime_class is explicitly specified in the config passed' do
        let(:default_runtime_class) { "test" }

        it_behaves_like 'successful update'
      end

      context 'when annotations is explicitly specified in the config passed' do
        let(:annotations) { { a: "1" } }

        it_behaves_like 'successful update'
      end

      context 'when labels is explicitly specified in the config passed' do
        let(:labels) { { b: "2" } }

        it_behaves_like 'successful update'
      end

      context "with existing workspaces_agent_config" do
        let(:expected_configs_created) { 0 }
        let_it_be(:workspaces_agent_config, refind: true) do
          create(:workspaces_agent_config, dns_zone: dns_zone, agent: agent)
        end

        before do
          agent.reload
        end

        it_behaves_like 'successful update'

        context 'when the dns_zone has been updated' do
          let_it_be(:new_dns_zone) { 'new-dns-zone.test' }
          let(:expected_dns_zone) { new_dns_zone }
          let(:dns_zone_in_config) { new_dns_zone }

          it_behaves_like 'successful update'

          it 'updates the dns_zone' do
            expect { result }.to change { workspaces_agent_config.reload.dns_zone }.from(dns_zone).to(new_dns_zone)
          end

          context 'when workspaces are present' do
            let_it_be(:non_terminated_workspace, refind: true) do
              create(
                :workspace,
                agent: agent,
                actual_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
                desired_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
                dns_zone: dns_zone,
                force_include_all_resources: false
              )
            end

            let_it_be(:terminated_workspace, refind: true) do
              create(
                :workspace,
                agent: agent,
                actual_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
                desired_state: RemoteDevelopment::WorkspaceOperations::States::TERMINATED,
                dns_zone: dns_zone,
                force_include_all_resources: false
              )
            end

            it_behaves_like 'successful update'

            it 'updates workspaces in a non-terminated state to force update' do
              expect { result }
                .to change { non_terminated_workspace.reload.force_include_all_resources }.from(false).to(true)
            end

            it 'updates the dns_zone of a workspace with desired_state non-terminated' do
              expect { result }.to change { non_terminated_workspace.reload.dns_zone }.from(dns_zone).to(new_dns_zone)
            end

            it 'does not update workspaces in a terminated state to force update' do
              expect { result }.not_to change { terminated_workspace.reload.force_include_all_resources }
            end

            context 'when workspaces update_all fails' do
              before do
                # rubocop:disable RSpec/AnyInstanceOf -- allow_next_instance_of does not work here
                allow_any_instance_of(RemoteDevelopment::WorkspacesAgentConfig)
                  .to receive_message_chain(:workspaces, :desired_state_not_terminated, :touch_all)
                allow_any_instance_of(RemoteDevelopment::WorkspacesAgentConfig)
                  .to receive_message_chain(:workspaces, :desired_state_not_terminated, :update_all)
                        .and_raise(ActiveRecord::ActiveRecordError, "SOME ERROR")
                # rubocop:enable RSpec/AnyInstanceOf
              end

              it 'returns an error result' do
                expect { result }.not_to change { RemoteDevelopment::WorkspacesAgentConfig.count }
                expect(result).to be_err_result do |message|
                  expect(message).to be_a(RemoteDevelopment::Messages::AgentConfigUpdateFailed)
                  message.content => { details: String => details }
                  expect(details).to eq(
                    "Error updating associated workspaces with update_all: SOME ERROR"
                  )
                end
                expect(terminated_workspace.reload.force_include_all_resources).to eq(false)
              end
            end
          end
        end
      end
    end

    context 'when config file is invalid' do
      context 'when dns_zone is invalid' do
        let(:dns_zone) { "invalid dns zone" }

        it 'does not create the record and returns error' do
          expect { result }.to not_change { RemoteDevelopment::WorkspacesAgentConfig.count }
          expect(agent.reload.workspaces_agent_config).to be_nil

          expect(result).to be_err_result do |message|
            expect(message).to be_a(RemoteDevelopment::Messages::AgentConfigUpdateFailed)
            message.content => { errors: ActiveModel::Errors => errors }
            expect(errors.full_messages.join(', ')).to match(/dns zone/i)
          end
        end
      end

      context 'when allow_privilege_escalation is explicitly specified in the config passed' do
        let(:allow_privilege_escalation) { true }

        it 'does not create the record and returns error' do
          expect { result }.to not_change { RemoteDevelopment::WorkspacesAgentConfig.count }
          expect(agent.reload.workspaces_agent_config).to be_nil

          expect(result).to be_err_result do |message|
            expect(message).to be_a(RemoteDevelopment::Messages::AgentConfigUpdateFailed)
            message.content => { errors: ActiveModel::Errors => errors }
            expect(errors.full_messages.join(', ')).to match(/allow privilege escalation/i)
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
