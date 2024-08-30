# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies, feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:namespace_policies_repository) { create(:project, :repository) }
  let_it_be(:namespace_security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      namespace: namespace,
      security_policy_management_project: namespace_policies_repository
    )
  end

  let_it_be(:project) { create(:project, :repository, group: namespace) }
  let_it_be(:policies_repository) { create(:project, :repository, group: namespace) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policies_repository
    )
  end

  let(:namespace_policy) { build(:pipeline_execution_policy) }
  let(:policy) { build(:pipeline_execution_policy) }

  let(:disabled_namespace_policy) { build(:pipeline_execution_policy, enabled: false) }
  let(:disabled_policy) { build(:pipeline_execution_policy, enabled: false) }

  let(:policy_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: [policy, disabled_policy]) }
  let(:namespace_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [namespace_policy, disabled_namespace_policy])
  end

  let(:licensed_feature_enabled) { true }

  before do
    stub_licensed_features(security_orchestration_policies: licensed_feature_enabled)
    allow_next_instance_of(Repository, anything, anything, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
    end

    allow_next_instance_of(Repository, anything, namespace_policies_repository, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(namespace_policy_yaml)
    end
  end

  describe '#configs' do
    subject(:configs) { described_class.new(project).configs }

    it 'includes configs of policies ordered by hierarchy' do
      # We use `eq` because we want to verify the order
      expect(configs).to eq([
        build_execution_policy_config(policy: policy, suffix: "#{policies_repository.id}-0"),
        build_execution_policy_config(policy: namespace_policy, suffix: "#{namespace_policies_repository.id}-0")
      ])
    end

    describe 'limits' do
      let(:project_policies) { build_list(:pipeline_execution_policy, 3) }
      let(:policy_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: project_policies) }
      let(:namespace_policies) { build_list(:pipeline_execution_policy, 3) }
      let(:namespace_policy_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: namespace_policies) }

      it 'includes configs for up to 5 policies, giving precedence to groups higher in the hierarchy' do
        expect(configs.size).to eq(5)
        expect(configs).to eq([
          build_execution_policy_config(policy: project_policies[1], suffix: "#{policies_repository.id}-1"),
          build_execution_policy_config(policy: project_policies[0], suffix: "#{policies_repository.id}-0"),
          build_execution_policy_config(policy: namespace_policies[2], suffix: "#{namespace_policies_repository.id}-2"),
          build_execution_policy_config(policy: namespace_policies[1], suffix: "#{namespace_policies_repository.id}-1"),
          build_execution_policy_config(policy: namespace_policies[0], suffix: "#{namespace_policies_repository.id}-0")
        ])
      end
    end

    describe 'policy_scope' do
      let(:namespace_policy) do
        build(:pipeline_execution_policy, policy_scope: { projects: { excluding: [{ id: project.id }] } })
      end

      it 'excludes the namespace policy from the configs' do
        expect(configs).to eq([build_execution_policy_config(policy: policy, suffix: "#{policies_repository.id}-0")])
      end
    end

    context 'when project has no group' do
      let_it_be(:project) { create(:project, :repository) }
      let_it_be(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration,
          project: project,
          security_policy_management_project: policies_repository)
      end

      it 'only includes project policy config' do
        expect(configs).to eq([build_execution_policy_config(policy: policy, suffix: "#{policies_repository.id}-0")])
      end
    end

    context 'when feature is not licensed' do
      let(:licensed_feature_enabled) { false }

      it 'returns empty array' do
        expect(configs).to be_empty
      end
    end
  end

  private

  def build_execution_policy_config(policy:, suffix:)
    build(:execution_policy_config, content: policy[:content].to_yaml, suffix: ":policy-#{suffix}")
  end
end
