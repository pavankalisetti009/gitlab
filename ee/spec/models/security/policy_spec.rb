# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policy, feature_category: :security_policy_management do
  subject(:policy) { create(:security_policy, :require_approval) }

  describe 'associations' do
    it { is_expected.to belong_to(:security_orchestration_policy_configuration) }
    it { is_expected.to have_many(:approval_policy_rules) }
    it { is_expected.to have_many(:security_policy_project_links) }
    it { is_expected.to have_many(:projects).through(:security_policy_project_links) }

    it do
      is_expected.to validate_uniqueness_of(:security_orchestration_policy_configuration_id).scoped_to(%i[type
        policy_index])
    end
  end

  describe 'validations' do
    shared_examples 'validates policy content' do
      it { is_expected.to be_valid }

      context 'with invalid content' do
        before do
          policy.content = { foo: "bar" }
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'content' do
      context 'when policy_type is approval_policy' do
        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is scan_execution_policy' do
        subject(:policy) { create(:security_policy, :scan_execution_policy) }

        it_behaves_like 'validates policy content'
      end

      context 'when policy_type is pipeline_execution_policy' do
        subject(:policy) { create(:security_policy, :pipeline_execution_policy) }

        it_behaves_like 'validates policy content'
      end
    end

    describe 'scope' do
      it { is_expected.to be_valid }

      context 'with empty scope' do
        before do
          policy.scope = {}
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid scope' do
        before do
          policy.scope = { foo: "bar" }
        end

        it { is_expected.to be_invalid }
      end
    end
  end

  describe '.undeleted' do
    let_it_be(:policy_with_positive_index) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy_with_zero_index) { create(:security_policy, policy_index: 0) }
    let_it_be(:policy_with_negative_index) { create(:security_policy, policy_index: -1) }

    it 'returns policies with policy_index greater than or equal to 0' do
      result = described_class.undeleted

      expect(result).to contain_exactly(policy_with_positive_index, policy_with_zero_index)
      expect(result).not_to include(policy_with_negative_index)
    end
  end

  describe '.order_by_index' do
    let_it_be(:policy1) { create(:security_policy, policy_index: 2) }
    let_it_be(:policy2) { create(:security_policy, policy_index: 1) }
    let_it_be(:policy3) { create(:security_policy, policy_index: 3) }

    it 'orders policies by policy_index in ascending order' do
      ordered_policies = described_class.order_by_index

      expect(ordered_policies).to match_array([policy2, policy1, policy3])
    end
  end

  describe '.upsert_policy' do
    shared_examples 'upserts policy' do |policy_type, assoc_name|
      let(:policy_configuration) { create(:security_orchestration_policy_configuration) }
      let(:policies) { policy_configuration.security_policies.where(type: policy_type) }
      let(:policy_index) { 0 }
      let(:upserted_rules) do
        assoc_name ? upserted_policy.association(assoc_name.to_s).load_target : []
      end

      subject(:upsert!) do
        described_class.upsert_policy(policy_type, policies, policy_hash, policy_index, policy_configuration)
      end

      context 'when the policy does not exist' do
        let(:upserted_policy) { policy_configuration.security_policies.last }

        it 'creates a new policy' do
          expect { upsert! }.to change { policies.count }.by(1)
          expect(upserted_policy.name).to eq(policy_hash[:name])
          expect(upserted_rules.count).to be(assoc_name ? 1 : 0)
        end
      end

      context 'with existing policy' do
        let!(:existing_policy) do
          create(:security_policy,
            policy_type,
            security_orchestration_policy_configuration: policy_configuration,
            policy_index: policy_index)
        end

        let(:upserted_policy) { existing_policy.reload }

        it 'updates the policy' do
          expect { upsert! }.not_to change { policies.count }
          expect(upserted_policy).to eq(existing_policy)
          expect(upserted_policy.name).to eq(policy_hash[:name])
          expect(upserted_rules.count).to be(assoc_name ? 1 : 0)
        end
      end
    end

    context "with approval policies" do
      include_examples 'upserts policy', :approval_policy, :approval_policy_rules do
        let(:policy_hash) { build(:approval_policy, name: "foobar") }
      end
    end

    context "with scan execution policies" do
      include_examples 'upserts policy', :scan_execution_policy, :scan_execution_policy_rules do
        let(:policy_hash) { build(:scan_execution_policy, name: "foobar") }
      end
    end

    context "with pipeline execution policies" do
      include_examples 'upserts policy', :pipeline_execution_policy, nil do
        let(:policy_hash) { build(:pipeline_execution_policy, name: "foobar") }
      end
    end
  end

  describe '.delete_by_ids' do
    let_it_be(:policies) { create_list(:security_policy, 3) }

    subject(:delete!) { described_class.delete_by_ids(policies.first(2).pluck(:id)) }

    it 'deletes by ID' do
      expect { delete! }.to change { described_class.all }.to(contain_exactly(policies.last))
    end
  end

  describe '#to_policy_hash' do
    subject(:policy_hash) { policy.to_policy_hash }

    context 'when policy is an approval policy' do
      let_it_be(:policy) { create(:security_policy, :require_approval) }

      let_it_be(:rule_content) do
        {
          type: 'scan_finding',
          branches: [],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      before do
        create(:approval_policy_rule, :scan_finding, security_policy: policy, content: rule_content)
      end

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          metadata: {},
          actions: [{ approvals_required: 1, type: "require_approval", user_approvers: ["owner"] }],
          rules: [rule_content]
        )
      end
    end

    context 'when policy is a scan execution policy' do
      let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }

      before do
        create(:scan_execution_policy_rule, :pipeline, security_policy: policy)
      end

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          metadata: {},
          actions: [{ scan: 'secret_detection' }],
          rules: [{ type: 'pipeline', branches: [] }]
        )
      end
    end

    context 'when policy is a pipeline execution policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_policy) }

      it 'returns the correct hash structure' do
        expect(policy_hash).to eq(
          name: policy.name,
          description: policy.description,
          enabled: true,
          policy_scope: {},
          metadata: {},
          pipeline_config_strategy: 'inject_ci',
          content: { include: [{ file: "compliance-pipeline.yml", project: "compliance-project" }] }
        )
      end
    end
  end

  describe '#rules' do
    let_it_be(:approval_policy) { create(:security_policy, :require_approval) }
    let_it_be(:scan_execution_policy) { create(:security_policy, :scan_execution_policy) }
    let_it_be(:pipeline_execution_policy) { create(:security_policy, :pipeline_execution_policy) }

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: approval_policy) }

    let_it_be(:negative_index_ap_rule) do
      create(:approval_policy_rule, security_policy: approval_policy, rule_index: -1)
    end

    let_it_be(:scan_execution_policy_rule) do
      create(:scan_execution_policy_rule, security_policy: scan_execution_policy)
    end

    let_it_be(:negative_index_se_rule) do
      create(:scan_execution_policy_rule, security_policy: scan_execution_policy, rule_index: -1)
    end

    subject(:rules) { policy.rules }

    context 'when policy is an approval policy' do
      let(:policy) { approval_policy }

      it { is_expected.to contain_exactly(approval_policy_rule) }
    end

    context 'when policy is a scan execution policy' do
      let(:policy) { scan_execution_policy }

      it { is_expected.to contain_exactly(scan_execution_policy_rule) }
    end

    context 'when policy is a pipeline execution policy' do
      let(:policy) { pipeline_execution_policy }

      it { is_expected.to be_empty }
    end
  end

  describe '#scope_applicable?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy) }

    let(:policy_scope_checker) { instance_double(Security::SecurityOrchestrationPolicies::PolicyScopeChecker) }

    before do
      allow(Security::SecurityOrchestrationPolicies::PolicyScopeChecker).to receive(:new)
        .with(project: project).and_return(policy_scope_checker)
    end

    subject(:scope_applicable) { policy.scope_applicable?(project) }

    context 'when the policy is applicable to the project' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy).and_return(true)
      end

      it { is_expected.to be true }
    end

    context 'when the policy is not applicable to the project' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy).and_return(false)
      end

      it { is_expected.to be false }
    end
  end
end
