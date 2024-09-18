# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicyRead, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:security_orchestration_policy_configuration) }
  end

  describe 'validations' do
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read) }

    subject { scan_result_policy_read }

    it { is_expected.not_to allow_value(nil).for(:role_approvers) }
    it { is_expected.to(validate_inclusion_of(:role_approvers).in_array(Gitlab::Access.values)) }

    it { is_expected.not_to allow_value(-1).for(:age_value) }
    it { is_expected.to allow_value(0, 1).for(:age_value) }
    it { is_expected.to allow_value(nil).for(:age_value) }

    it { is_expected.not_to allow_value("string").for(:vulnerability_attributes) }
    it { is_expected.to allow_value({}).for(:vulnerability_attributes) }

    it do
      is_expected.to allow_value({ false_positive: true, fix_available: false }).for(:vulnerability_attributes)
    end

    it { is_expected.not_to allow_value("string").for(:project_approval_settings) }
    it { is_expected.to allow_value({}).for(:project_approval_settings) }

    it { is_expected.not_to allow_value("string").for(:fallback_behavior) }
    it { is_expected.to allow_value({}).for(:fallback_behavior) }
    it { is_expected.to allow_value({ fail: described_class::FALLBACK_BEHAVIORS[:open] }).for(:fallback_behavior) }
    it { is_expected.to allow_value({ fail: described_class::FALLBACK_BEHAVIORS[:closed] }).for(:fallback_behavior) }
    it { is_expected.not_to allow_value({ fail: "foo" }).for(:fallback_behavior) }

    it do
      is_expected.to allow_value(
        { prevent_approval_by_author: true, prevent_approval_by_commit_author: false,
          remove_approvals_with_new_commit: true, require_password_to_approve: false,
          block_branch_modification: true, block_group_branch_modification: true }
      ).for(:project_approval_settings)
    end

    it do
      is_expected.to allow_value(
        { block_group_branch_modification: { enabled: true, exceptions: %w[foobar] } }
      ).for(:project_approval_settings)
    end

    it { is_expected.not_to allow_value('string').for(:send_bot_message) }
    it { is_expected.to allow_value({}).for(:send_bot_message) }
    it { is_expected.to allow_value({ enabled: true }).for(:send_bot_message) }
    it { is_expected.to allow_value({ enabled: false }).for(:send_bot_message) }
    it { is_expected.not_to allow_value({ enabled: 'foo' }).for(:send_bot_message) }

    it do
      is_expected.to(
        validate_uniqueness_of(:rule_idx)
          .scoped_to(%i[security_orchestration_policy_configuration_id project_id orchestration_policy_idx]))
    end

    it { is_expected.to validate_numericality_of(:rule_idx).is_greater_than_or_equal_to(0).only_integer }
  end

  describe 'enums' do
    let(:age_operator_values) { { greater_than: 0, less_than: 1 } }
    let(:age_interval_values) { { day: 0, week: 1, month: 2, year: 3 } }

    it { is_expected.to define_enum_for(:age_operator).with_values(**age_operator_values) }
    it { is_expected.to define_enum_for(:age_interval).with_values(**age_interval_values) }
  end

  describe 'scopes' do
    describe '.blocking_branch_modification' do
      let_it_be(:non_blocking_read) { create(:scan_result_policy_read) }
      let_it_be(:blocking_read) do
        create(:scan_result_policy_read, project_approval_settings: { block_branch_modification: true })
      end

      it 'returns blocking reads' do
        expect(described_class.blocking_branch_modification).to contain_exactly(blocking_read)
      end
    end

    describe '.prevent_pushing_and_force_pushing' do
      let_it_be(:non_blocking_read) { create(:scan_result_policy_read) }
      let_it_be(:blocking_read) do
        create(:scan_result_policy_read, project_approval_settings: { prevent_pushing_and_force_pushing: true })
      end

      it 'returns blocking reads' do
        expect(described_class.prevent_pushing_and_force_pushing).to contain_exactly(blocking_read)
      end
    end
  end

  describe '#newly_detected?' do
    subject { scan_result_policy_read.newly_detected? }

    context 'when license_states contains newly_detected' do
      let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, license_states: ['newly_detected']) }

      it { is_expected.to be_truthy }
    end

    context 'when license_states does not contain newly_detected' do
      let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, license_states: ['detected']) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#approval_policy_rule' do
    let(:scan_result_policy) { create(:scan_result_policy_read) }
    let(:policy_configuration) { scan_result_policy.security_orchestration_policy_configuration }

    context 'when real_policy_index is negative' do
      before do
        allow(scan_result_policy).to receive(:real_policy_index).and_return(-1)
      end

      it 'returns nil' do
        expect(scan_result_policy.approval_policy_rule).to be_nil
      end
    end

    context 'when real_policy_index is non-negative' do
      let(:real_policy_index) { 1 }
      let(:rule_idx) { 2 }
      let(:approval_policy_rule) { instance_double(Security::ApprovalPolicyRule) }

      before do
        allow(scan_result_policy).to receive(:real_policy_index).and_return(real_policy_index)
        allow(scan_result_policy).to receive(:rule_idx).and_return(rule_idx)
        allow(Security::ApprovalPolicyRule).to receive(:by_policy_rule_index).and_return(approval_policy_rule)
      end

      it 'calls Security::ApprovalPolicyRule.by_policy_rule_index with correct arguments' do
        expect(Security::ApprovalPolicyRule).to receive(:by_policy_rule_index)
          .with(policy_configuration, policy_index: real_policy_index, rule_index: rule_idx)

        scan_result_policy.approval_policy_rule
      end

      it 'returns the result from Security::ApprovalPolicyRule.by_policy_rule_index' do
        expect(scan_result_policy.approval_policy_rule).to eq(approval_policy_rule)
      end
    end
  end

  describe '#real_policy_index' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:scan_result_policy_read) do
      create(:scan_result_policy_read,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        orchestration_policy_idx: 1)
    end

    let_it_be(:policy_0) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 0,
        enabled: true)
    end

    let_it_be(:policy_1) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1,
        enabled: false)
    end

    let_it_be(:policy_2) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 2,
        enabled: true)
    end

    let_it_be(:policy_3) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 3,
        enabled: true)
    end

    let(:policy_scope_checker) { instance_double(Security::SecurityOrchestrationPolicies::PolicyScopeChecker) }

    before do
      allow(Security::SecurityOrchestrationPolicies::PolicyScopeChecker).to receive(:new)
        .with(project: project).and_return(policy_scope_checker)
      scan_result_policy_read.clear_memoization(:real_policy_index)
    end

    context 'when all policies are applicable' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).and_return(true)
      end

      it 'returns the correct index' do
        expect(scan_result_policy_read.real_policy_index).to eq(2)
      end
    end

    context 'when some policies are not applicable' do
      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).and_return(true)
        allow(policy_scope_checker).to receive(:security_policy_applicable?).with(policy_2).and_return(false)
      end

      it 'returns the correct index' do
        expect(scan_result_policy_read.real_policy_index).to eq(3)
      end
    end

    context 'when the target policy is not found' do
      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: policy_configuration,
          orchestration_policy_idx: 10)
      end

      before do
        allow(policy_scope_checker).to receive(:security_policy_applicable?).and_return(true)
      end

      it 'returns negative index' do
        expect(scan_result_policy_read.real_policy_index).to eq(-1)
      end
    end
  end

  describe '.for_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:scan_result_policy_read_1) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_3) { create(:scan_result_policy_read) }

    subject { described_class.for_project(project) }

    it 'returns records for given projects' do
      is_expected.to contain_exactly(scan_result_policy_read_1, scan_result_policy_read_2)
    end
  end

  describe '#vulnerability_age' do
    let_it_be(:scan_result_policy_read) do
      create(:scan_result_policy_read, age_operator: 'less_than', age_interval: 'day', age_value: 1)
    end

    subject { scan_result_policy_read.vulnerability_age }

    context 'when vulnerability age attributes are present' do
      it { is_expected.to eq({ operator: :less_than, interval: :day, value: 1 }) }
    end

    context 'when vulnerability age attributes are not present' do
      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read)
      end

      it { is_expected.to eq({}) }
    end
  end

  describe '#bot_message_disabled?' do
    subject { scan_result_policy_read.bot_message_disabled? }

    let_it_be(:project) { create(:project) }
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let(:scan_result_policy_read) do
      create(:scan_result_policy_read, :with_send_bot_message, project: project, bot_message_enabled: false)
    end

    it { is_expected.to eq true }

    context 'when send_bot_message data is present and enabled is true' do
      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, :with_send_bot_message, project: project, bot_message_enabled: true)
      end

      it { is_expected.to eq false }
    end

    context 'when send_bot_message data is not present' do
      let(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

      it { is_expected.to eq false }
    end
  end

  describe "#fail_open?" do
    subject(:fail_open) { read.fail_open? }

    context "when failing open" do
      let(:read) { create(:scan_result_policy_read, :fail_open) }

      it { is_expected.to be(true) }
    end

    context "when failing closed" do
      let(:read) { create(:scan_result_policy_read, :fail_closed) }

      it { is_expected.to be(false) }
    end

    context "without fallback_behavior" do
      let(:read) { create(:scan_result_policy_read) }

      it { is_expected.to be(false) }
    end
  end
end
