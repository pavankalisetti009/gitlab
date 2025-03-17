# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceRequirements::ProjectFields, feature_category: :compliance_management do
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  describe '.map_field' do
    it 'defines expected field mappings' do
      expect(described_class::FIELD_MAPPINGS.keys).to contain_exactly(
        'default_branch_protected',
        'merge_request_prevent_author_approval',
        'merge_request_prevent_committers_approval',
        'project_visibility',
        'minimum_approvals_required',
        'auth_sso_enabled'
      )
    end

    describe 'default_branch_protected' do
      it 'calls ProtectedBranch#protected?' do
        expect(ProtectedBranch).to receive(:protected?).with(project, project.default_branch)

        described_class.map_field(project, 'default_branch_protected')
      end
    end

    describe 'merge_request_prevent_author_approval' do
      it 'calls merge_requests_author_approval? on project' do
        expect(project).to receive(:merge_requests_author_approval?)

        described_class.map_field(project, 'merge_request_prevent_author_approval')
      end
    end

    describe 'merge_request_prevent_committers_approval' do
      it 'calls merge_requests_disable_committers_approval? on project' do
        expect(project).to receive(:merge_requests_disable_committers_approval?)

        described_class.map_field(project, 'merge_request_prevent_committers_approval')
      end
    end

    describe 'project_visibility' do
      it 'calls visibility on project' do
        expect(project).to receive(:visibility)

        described_class.map_field(project, 'project_visibility')
      end
    end

    describe 'minimum_approvals_required' do
      it 'calls pick on project approval rules' do
        expect(project.approval_rules).to receive(:pick).with("SUM(approvals_required)")

        described_class.map_field(project, 'minimum_approvals_required')
      end
    end

    describe 'auth_sso_enabled' do
      it 'calls Groups::SsoHelper.saml_provider_enabled? with project.group' do
        expect(::Groups::SsoHelper).to receive(:saml_provider_enabled?).with(project.group)

        described_class.map_field(project, 'auth_sso_enabled')
      end

      context 'when SAML provider is enabled' do
        before do
          allow(::Groups::SsoHelper).to receive(:saml_provider_enabled?).with(project.group).and_return(true)
        end

        it 'returns true' do
          expect(described_class.map_field(project, 'auth_sso_enabled')).to be true
        end
      end

      context 'when SAML provider is not enabled' do
        before do
          allow(::Groups::SsoHelper).to receive(:saml_provider_enabled?).with(project.group).and_return(false)
        end

        it 'returns false' do
          expect(described_class.map_field(project, 'auth_sso_enabled')).to be false
        end
      end

      context 'when project has no group' do
        let_it_be(:project_without_group) { create(:project) }

        it 'returns false' do
          expect(described_class.map_field(project_without_group, 'auth_sso_enabled')).to be false
        end
      end
    end
  end
end
