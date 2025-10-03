# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService, feature_category: :security_policy_management do
  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be(:policy_project) { create(:project, :repository) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }
  let(:branch_name) { protected_branch.name }
  let_it_be_with_refind(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: protected_branch.project,
      security_policy_management_project: policy_project)
  end

  subject(:result) { described_class.new(project: project).execute }

  before_all do
    project.repository.add_branch(project.creator, protected_branch.name, "HEAD")
  end

  context 'without blocking scan result policy' do
    it { is_expected.to be_empty }
  end

  context 'with blocking scan result policy' do
    include_context 'with approval policy preventing force pushing'

    it 'includes the protected branch' do
      expect(result).to include(branch_name)
    end

    it_behaves_like 'when no policy is applicable due to the policy scope' do
      it { is_expected.to be_empty }
    end

    context 'with branch is not protected' do
      let(:branch_name) { 'feature-x' }

      it { is_expected.to be_empty }
    end

    context 'when policy is not preventing force pushing' do
      let(:prevent_pushing_and_force_pushing) { false }

      it { is_expected.to be_empty }
    end

    context 'with warn mode' do
      let(:approval_policy) do
        build(:approval_policy, branches: [branch_name],
          approval_settings: { prevent_pushing_and_force_pushing: prevent_pushing_and_force_pushing },
          enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN)
      end

      it { is_expected.to be_empty }

      context 'with feature disabled' do
        before do
          stub_feature_flags(security_policy_approval_warn_mode: false)
        end

        it 'includes the protected branch' do
          expect(result).to include(branch_name)
        end
      end
    end
  end
end
