# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService, "#execute", feature_category: :security_policy_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:policy_project) { create(:project, :repository) }
  let(:service) { described_class.new(group: group, params: params) }
  let_it_be(:group) { build(:group) }
  let_it_be(:policy_config) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      security_policy_management_project: policy_project,
      namespace: group)
  end

  let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [], approval_policy: policies) }
  let(:policies) { [policy] }
  let(:policy) { build(:approval_policy, approval_settings: approval_settings) }
  let(:approval_settings) do
    { block_branch_modification: block_branch_modification,
      block_group_branch_modification: block_group_branch_modification }.compact
  end

  let(:params) { {} }

  before do
    allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |repo|
      allow(repo).to receive(:policy_blob)
        .and_return(policy_yaml)
    end
  end

  subject(:execute) { service.execute }

  where(:block_branch_modification, :block_group_branch_modification, :expectation) do
    true | nil   | true
    true | true  | true
    true | false | false
    nil  | nil   | false
    nil  | true  | true
    nil  | false | false

    true | { enabled: true }  | true
    true | { enabled: false } | false
    nil  | { enabled: true }  | true
    nil  | { enabled: false } | false

    true  | { enabled: true, exceptions: [{ id: lazy { group.id } }] }  | false
    true  | { enabled: false, exceptions: [{ id: lazy { group.id } }] } | false
    false | { enabled: true, exceptions: [{ id: lazy { group.id } }] }  | false
    false | { enabled: false, exceptions: [{ id: lazy { group.id } }] } | false

    true  | { enabled: true, exceptions: [{ id: lazy { non_existing_record_id } }] }  | true
    true  | { enabled: false, exceptions: [{ id: lazy { non_existing_record_id } }] } | false
    false | { enabled: true, exceptions: [{ id: lazy { non_existing_record_id } }] }  | true
    false | { enabled: false, exceptions: [{ id: lazy { non_existing_record_id } }] } | false
  end

  with_them do
    it { is_expected.to be(expectation) }
  end

  context 'without approval_settings' do
    let(:approval_settings) { nil }

    it { is_expected.to be(false) }
  end

  context 'with conflicting settings' do
    let(:policies) do
      [build(:approval_policy, approval_settings: { block_group_branch_modification: true }),
        build(:approval_policy, approval_settings: { block_group_branch_modification: false })]
    end

    it { is_expected.to be(true) }
  end

  context 'with warn mode policy' do
    let(:block_branch_modification) { true }
    let(:block_group_branch_modification) { true }

    let(:policy) do
      build(:approval_policy,
        approval_settings: approval_settings,
        enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN)
    end

    context 'with default-enforced policies only' do
      let(:params) { {} }

      it { is_expected.to be(false) }
    end

    context 'with warn mode policies only' do
      let(:params) { { policy_enforcement_type: ::Security::Policy::ENFORCEMENT_TYPE_WARN } }

      it { is_expected.to be(true) }

      context 'when ignore_warn_mode is true' do
        let(:service) { described_class.new(group: group, params: params, ignore_warn_mode: true) }

        it { is_expected.to be(false) }
      end
    end
  end

  context 'when collecting blocking policies' do
    let(:params) { { collect_blocking_policies: true } }

    let(:blocking_policy_1) { build(:approval_policy, approval_settings: { block_group_branch_modification: true }) }
    let(:non_blocking_policy) { build(:approval_policy, approval_settings: { block_group_branch_modification: false }) }
    let(:blocking_policy_2) { build(:approval_policy, approval_settings: { block_branch_modification: true }) }

    let(:policies) do
      [
        blocking_policy_1,
        non_blocking_policy,
        blocking_policy_2
      ]
    end

    it 'returns true and collects blocking policies', :aggregate_failures do
      expect(service.execute).to be(true)
      expect(service.blocking_policies).to contain_exactly(
        have_attributes(policy_configuration_id: policy_config.id,
          security_policy_name: blocking_policy_1[:name]),
        have_attributes(policy_configuration_id: policy_config.id,
          security_policy_name: blocking_policy_2[:name])
      )
    end

    context 'when no policies are blocking' do
      let(:policies) { [non_blocking_policy] }

      it 'returns false and collects no blocking policies' do
        expect(service.execute).to be(false)
        expect(service.blocking_policies).to be_empty
      end
    end

    context 'with warn mode policies' do
      let(:warn_mode_blocking_policy) do
        build(:approval_policy,
          approval_settings: { block_group_branch_modification: true },
          enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN)
      end

      let(:default_blocking_policy) { blocking_policy_1 }

      let(:policies) { [warn_mode_blocking_policy, default_blocking_policy] }

      context 'when filtering for default-enforced policies (default behavior)' do
        let(:params) { { collect_blocking_policies: true } }

        it 'collects blocking default-enforced policy' do
          expect(service.execute).to be(true)
          expect(service.blocking_policies).to contain_exactly(
            have_attributes(policy_configuration_id: policy_config.id,
              security_policy_name: default_blocking_policy[:name]))
        end
      end

      context 'when filtering for warn mode policies' do
        let(:params) do
          { collect_blocking_policies: true, policy_enforcement_type: ::Security::Policy::ENFORCEMENT_TYPE_WARN }
        end

        it 'collects blocking warn mode policies' do
          expect(service.execute).to be(true)
          expect(service.blocking_policies).to contain_exactly(
            have_attributes(policy_configuration_id: policy_config.id,
              security_policy_name: warn_mode_blocking_policy[:name]))
        end
      end
    end
  end
end
