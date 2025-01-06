# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  subject(:context) do
    described_class.new(project: project, ref: ref, current_user: user, source: source)
  end

  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:ref) { 'refs/heads/master' }
  let(:source) { 'push' }
  let(:pipeline) { build(:ci_pipeline, source: source, project: project, ref: ref, user: user) }

  let_it_be(:policies_repository) { create(:project, :repository) }
  let(:feature_licensed) { true }
  let_it_be(:security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policies_repository
    )
  end

  let(:policy) do
    build(:scan_execution_policy, actions: [
      { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' },
      { scan: 'secret_detection' },
      { scan: 'dependency_scanning' }
    ])
  end

  let(:policy_duplicated_action) do
    build(:scan_execution_policy, actions: [{ scan: 'dependency_scanning' }])
  end

  let(:disabled_policy) do
    build(:scan_execution_policy, enabled: false, actions: [{ scan: 'sast_iac' }])
  end

  let(:inapplicable_policy) do
    build(:scan_execution_policy,
      actions: [{ scan: 'container_scanning' }],
      rules: [{ type: 'pipeline', branches: %w[other] }])
  end

  let(:policy_yaml) do
    build(:orchestration_policy_yaml,
      scan_execution_policy: [policy, policy_duplicated_action, disabled_policy, inapplicable_policy])
  end

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
    allow_next_instance_of(Repository, anything, anything, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
    end
  end

  describe '#has_scan_execution_policies?' do
    let_it_be_with_reload(:db_policy) do
      create(:security_policy, :scan_execution_policy, linked_projects: [project],
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    subject { context.has_scan_execution_policies? }

    it { is_expected.to be(true) }

    context 'when no policies are returned' do
      let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: []) }

      it { is_expected.to be(false) }
    end

    context 'when no scan execution policies are associated with the project in the database' do
      before do
        db_policy.destroy!
      end

      it { is_expected.to be(false) }
    end

    context 'when ref is not for a branch' do
      let(:ref) { 'master' }

      it { is_expected.to be(false) }
    end

    context 'when source is not a ci source' do
      let(:source) { 'ondemand_dast_scan' }

      it { is_expected.to be(false) }
    end

    context 'when source is nil' do
      let(:source) { nil }

      it { is_expected.to be(false) }
    end

    context 'when feature is not licensed' do
      let(:feature_licensed) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '#active_scan_execution_actions' do
    it 'returns the active scan execution actions' do
      expect(context.active_scan_execution_actions).to match_array(policy[:actions])
    end
  end
end
