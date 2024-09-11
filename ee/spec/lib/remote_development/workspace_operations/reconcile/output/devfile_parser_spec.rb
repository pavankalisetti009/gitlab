# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DevfileParser, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:dns_zone) { "workspaces.localdev.me" }
  let(:logger) { instance_double(Logger) }
  let(:user) { instance_double("User", name: "name", email: "name@example.com") }
  let(:agent) { instance_double("Clusters::Agent", id: 1) }
  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace",
      id: 1,
      name: "name",
      namespace: "namespace",
      deployment_resource_version: "1",
      desired_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
      actual_state: RemoteDevelopment::WorkspaceOperations::States::STOPPED,
      dns_zone: dns_zone,
      processed_devfile: example_processed_devfile,
      user: user,
      agent: agent
    )
  end

  let(:domain_template) { "{{.port}}-#{workspace.name}.#{workspace.dns_zone}" }
  let(:environment_secret_name) { "#{workspace.name}-env-var" }
  let(:file_secret_name) { "#{workspace.name}-file" }
  let(:egress_ip_rules)  do
    [{
      allow: "0.0.0.0/0",
      except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
    }]
  end

  let(:max_resources_per_workspace) { {} }
  let(:default_resources_per_workspace_container) do
    { limits: { cpu: "1.5", memory: "786Mi" }, requests: { cpu: "0.6", memory: "512Mi" } }
  end

  let(:allow_privilege_escalation) { false }
  let(:use_kubernetes_user_namespaces) { false }
  let(:default_runtime_class) { "test" }
  let(:agent_labels) { { a: "1" } }
  let(:agent_annotations) { { b: "2" } }

  let(:expected_workspace_resources) do
    YAML.load_stream(
      create_config_to_apply(
        workspace: workspace,
        workspace_variables_environment: {},
        workspace_variables_file: {},
        started: true,
        include_inventory: false,
        include_network_policy: false,
        include_all_resources: false,
        dns_zone: dns_zone,
        egress_ip_rules: egress_ip_rules,
        default_resources_per_workspace_container: default_resources_per_workspace_container,
        allow_privilege_escalation: allow_privilege_escalation,
        use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
        default_runtime_class: default_runtime_class,
        agent_labels: agent_labels,
        agent_annotations: agent_annotations
      )
    )
  end

  let(:k8s_resources_params_class) do
    RemoteDevelopment::WorkspaceOperations::Reconcile::Output::KubernetesResourcesParams
  end

  subject(:devfile_parser) do
    described_class
  end

  shared_examples 'successfully generation of workspace_resources' do
    it 'returns workspace_resources' do
      extra_labels = { 'agent.gitlab.com/id' => workspace.agent.id }
      labels = agent_labels.merge(extra_labels)
      extra_annotations = {
        'config.k8s.io/owning-inventory' => "#{workspace.name}-workspace-inventory",
        'workspaces.gitlab.com/host-template' => domain_template,
        'workspaces.gitlab.com/id' => workspace.id,
        'workspaces.gitlab.com/max-resources-per-workspace-sha256' =>
          Digest::SHA256.hexdigest(max_resources_per_workspace.sort.to_h.to_s)
      }
      annotations = agent_annotations.merge(extra_annotations)

      k8s_resources_params = {
        name: workspace.name,
        namespace: workspace.namespace,
        replicas: 1,
        domain_template: domain_template,
        labels: labels,
        annotations: annotations,
        env_secret_names: [environment_secret_name],
        file_secret_names: [file_secret_name],
        default_resources_per_workspace_container: default_resources_per_workspace_container,
        allow_privilege_escalation: allow_privilege_escalation,
        use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
        default_runtime_class: default_runtime_class
      }

      workspace_resources = devfile_parser.get_all(
        processed_devfile: example_processed_devfile,
        k8s_resources_params: k8s_resources_params,
        logger: logger
      )

      expect(workspace_resources).to eq(expected_workspace_resources)
    end
  end

  it_behaves_like 'successfully generation of workspace_resources'

  context "when allow_privilege_escalation is true" do
    let(:allow_privilege_escalation) { true }

    it_behaves_like 'successfully generation of workspace_resources'
  end

  context "when use_kubernetes_user_namespaces is true" do
    let(:use_kubernetes_user_namespaces) { true }

    it_behaves_like 'successfully generation of workspace_resources'
  end

  context "when allow_privilege_escalation and use_kubernetes_user_namespaces are true" do
    let(:allow_privilege_escalation) { true }
    let(:use_kubernetes_user_namespaces) { true }

    it_behaves_like 'successfully generation of workspace_resources'
  end

  context "when Devfile::CliError is raised" do
    before do
      allow(Devfile::Parser).to receive(:get_all).and_raise(Devfile::CliError.new("some error"))
    end

    it "logs the error" do
      expect(logger).to receive(:warn).with(
        message: 'Error parsing devfile with Devfile::Parser.get_all',
        error_type: 'reconcile_devfile_parser_error',
        workspace_name: workspace.name,
        workspace_namespace: workspace.namespace,
        devfile_parser_error: "some error"
      )

      k8s_resources_params = {
        name: workspace.name,
        namespace: workspace.namespace,
        replicas: 1,
        domain_template: "",
        labels: {},
        annotations: {},
        env_secret_names: [environment_secret_name],
        file_secret_names: [file_secret_name],
        default_resources_per_workspace_container: default_resources_per_workspace_container,
        allow_privilege_escalation: allow_privilege_escalation,
        use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
        default_runtime_class: default_runtime_class
      }

      workspace_resources = devfile_parser.get_all(
        processed_devfile: "",
        k8s_resources_params: k8s_resources_params,
        logger: logger
      )

      expect(workspace_resources).to eq([])
    end
  end
end
