# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceRequirements::ProjectFields, feature_category: :compliance_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  describe '.map_field' do
    before do
      allow(ComplianceManagement::ComplianceFramework::Controls::Registry).to receive(:field_mappings)
        .and_return(
          'default_branch_protected' => :default_branch_protected?,
          'merge_request_prevent_author_approval' => :merge_request_prevent_author_approval?,
          'merge_request_prevent_committers_approval' => :merge_requests_disable_committers_approval?,
          'project_visibility' => :project_visibility,
          'minimum_approvals_required' => :minimum_approvals_required,
          'auth_sso_enabled' => :auth_sso_enabled?,
          'scanner_sast_running' => :scanner_sast_running?,
          'scanner_secret_detection_running' => :scanner_secret_detection_running?,
          'scanner_dep_scanning_running' => :scanner_dep_scanning_running?,
          'scanner_container_scanning_running' => :scanner_container_scanning_running?,
          'scanner_license_compliance_running' => :scanner_license_compliance_running?,
          'scanner_dast_running' => :scanner_dast_running?,
          'scanner_api_security_running' => :scanner_api_security_running?,
          'scanner_fuzz_testing_running' => :scanner_fuzz_testing_running?,
          'scanner_code_quality_running' => :scanner_code_quality_running?,
          'scanner_iac_running' => :scanner_iac_running?,
          'terraform_enabled' => :terraform_enabled?
        )

      allow(project).to receive(:default_branch).and_return('main')
    end

    it 'defines expected field mappings from Registry' do
      expect(described_class::FIELD_MAPPINGS.keys).to contain_exactly(
        'default_branch_protected',
        'merge_request_prevent_author_approval',
        'merge_request_prevent_committers_approval',
        'project_visibility',
        'minimum_approvals_required',
        'auth_sso_enabled',
        'scanner_sast_running',
        'scanner_secret_detection_running',
        'scanner_dep_scanning_running',
        'scanner_container_scanning_running',
        'scanner_license_compliance_running',
        'scanner_dast_running',
        'scanner_api_security_running',
        'scanner_fuzz_testing_running',
        'scanner_code_quality_running',
        'scanner_iac_running',
        'code_changes_requires_code_owners',
        'reset_approvals_on_push',
        'status_checks_required',
        'require_branch_up_to_date',
        'resolve_discussions_required',
        'require_linear_history',
        'restrict_push_merge_access',
        'force_push_disabled',
        'terraform_enabled'
      )
    end

    it 'returns nil for unknown fields' do
      expect(described_class.map_field(project, 'unknown_field')).to be_nil
    end

    describe 'default_branch_protected' do
      it 'calls ProtectedBranch#protected?' do
        expect(ProtectedBranch).to receive(:protected?).with(project, project.default_branch)

        described_class.map_field(project, 'default_branch_protected')
      end

      context 'when default_branch is nil' do
        let(:project_without_default_branch) { build_stubbed(:project) }

        before do
          allow(project_without_default_branch).to receive(:default_branch).and_return(nil)
        end

        it 'returns false' do
          expect(described_class.map_field(project_without_default_branch, 'default_branch_protected')).to be false
        end
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

      context 'when no approval rules exist' do
        before do
          allow(project.approval_rules).to receive(:pick).and_return(nil)
        end

        it 'returns 0' do
          expect(described_class.map_field(project, 'minimum_approvals_required')).to eq(0)
        end
      end
    end

    describe 'auth_sso_enabled' do
      before do
        allow(project).to receive(:group).and_return(namespace)
      end

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

    describe 'scanner_sast_running' do
      it 'calls security_scanner_running? with scanner type sast' do
        expect(described_class).to receive(:security_scanner_running?).with(:sast, project)

        described_class.map_field(project, 'scanner_sast_running')
      end
    end

    describe 'scanner_secret_detection_running' do
      it 'calls security_scanner_running? with scanner type secret_detection' do
        expect(described_class).to receive(:security_scanner_running?).with(:secret_detection, project)

        described_class.map_field(project, 'scanner_secret_detection_running')
      end
    end

    describe 'scanner_dep_scanning_running' do
      it 'calls security_scanner_running? with scanner type dependency_scanning' do
        expect(described_class).to receive(:security_scanner_running?).with(:dependency_scanning, project)

        described_class.map_field(project, 'scanner_dep_scanning_running')
      end
    end

    describe 'scanner_container_scanning_running' do
      it 'calls security_scanner_running? with scanner type container_scanning' do
        expect(described_class).to receive(:security_scanner_running?).with(:container_scanning, project)

        described_class.map_field(project, 'scanner_container_scanning_running')
      end
    end

    describe 'scanner_license_compliance_running' do
      it 'calls security_scanner_running? with scanner type license_compliance' do
        expect(described_class).to receive(:security_scanner_running?).with(:license_compliance, project)

        described_class.map_field(project, 'scanner_license_compliance_running')
      end
    end

    describe 'scanner_dast_running' do
      it 'calls security_scanner_running? with scanner type dast' do
        expect(described_class).to receive(:security_scanner_running?).with(:dast, project)

        described_class.map_field(project, 'scanner_dast_running')
      end
    end

    describe 'scanner_api_security_running' do
      it 'calls security_scanner_running? with scanner type api_fuzzing' do
        expect(described_class).to receive(:security_scanner_running?).with(:api_fuzzing, project)

        described_class.map_field(project, 'scanner_api_security_running')
      end
    end

    describe 'scanner_fuzz_testing_running' do
      it 'calls security_scanner_running? with scanner type fuzz_testing' do
        expect(described_class).to receive(:security_scanner_running?).with(:fuzz_testing, project)

        described_class.map_field(project, 'scanner_fuzz_testing_running')
      end
    end

    describe 'scanner_code_quality_running' do
      it 'calls security_scanner_running? with scanner type code_quality' do
        expect(described_class).to receive(:security_scanner_running?).with(:code_quality, project)

        described_class.map_field(project, 'scanner_code_quality_running')
      end
    end

    describe 'scanner_iac_running' do
      it 'calls security_scanner_running? with scanner type iac' do
        expect(described_class).to receive(:security_scanner_running?).with(:iac, project)

        described_class.map_field(project, 'scanner_iac_running')
      end
    end

    describe 'security_scanner_running?' do
      let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
      let_it_be(:build) { create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project) }

      before do
        allow(project).to receive(:latest_successful_pipeline_for_default_branch).and_return(pipeline)
      end

      it 'returns true if the latest successful pipeline has the scanner job artifact' do
        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be true
      end

      it 'returns false if the latest successful pipeline does not have the scanner job artifact' do
        expect(described_class.send(:security_scanner_running?, :sast, project)).to be false
      end

      it 'returns false if the scanner is not supported' do
        expect(described_class.send(:security_scanner_running?, :foo, project)).to be false
      end

      it 'returns false if there is no latest successful pipeline' do
        project = create(:project, namespace: namespace)
        create(:ci_pipeline, project: project)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be false
      end

      it 'returns false if the latest pipeline has a scanner job artifact and has failed' do
        project = create(:project, namespace: namespace)
        pipeline = create(:ci_pipeline, :failed, project: project)
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be false
      end

      it 'returns false if the project has a successful pipeline with a job artifact for a non-default branch' do
        project = create(:project, :repository, namespace: namespace)
        pipeline = create(:ci_pipeline, :success, project: project, ref: 'non-default')
        create(:ci_build, :secret_detection_report, :success, pipeline: pipeline, project: project)

        expect(described_class.send(:security_scanner_running?, :secret_detection, project)).to be false
      end
    end

    describe '#code_changes_requires_code_owners?' do
      it 'delegates to ProtectedBranch.branch_requires_code_owner_approval?' do
        expect(ProtectedBranch).to receive(:branch_requires_code_owner_approval?)
          .with(project, nil)

        described_class.map_field(project, 'code_changes_requires_code_owners')
      end
    end

    describe '#reset_approvals_on_push?' do
      it 'delegates to project#reset_approvals_on_push' do
        expect(project).to receive(:reset_approvals_on_push)

        described_class.map_field(project, 'reset_approvals_on_push')
      end
    end

    describe '#status_checks_required?' do
      it 'delegates to project#only_allow_merge_if_all_status_checks_passed' do
        expect(project).to receive(:only_allow_merge_if_all_status_checks_passed)

        described_class.map_field(project, 'status_checks_required')
      end
    end

    describe '#require_branch_up_to_date?' do
      it 'returns true if the project merge_method is rebase_merge or ff' do
        expect(project).to receive(:merge_method).and_return(:rebase_merge)
        expect(described_class.map_field(project, 'require_branch_up_to_date')).to be true

        expect(project).to receive(:merge_method).and_return(:ff)
        expect(described_class.map_field(project, 'require_branch_up_to_date')).to be true
      end

      it 'returns false if the project merge_method is not rebase_merge or ff' do
        expect(project).to receive(:merge_method).and_return(:merge)
        expect(described_class.map_field(project, 'require_branch_up_to_date')).to be false
      end
    end

    describe '#resolve_discussions_required?' do
      it 'delegates to project#only_allow_merge_if_all_discussions_are_resolved' do
        expect(project).to receive(:only_allow_merge_if_all_discussions_are_resolved)

        described_class.map_field(project, 'resolve_discussions_required')
      end
    end

    describe '#require_linear_history?' do
      it 'returns false if the project merge_method is rebase_merge or merge' do
        expect(project).to receive(:merge_method).and_return(:rebase_merge)
        expect(described_class.map_field(project, 'require_linear_history')).to be false

        expect(project).to receive(:merge_method).and_return(:merge)
        expect(described_class.map_field(project, 'require_linear_history')).to be false
      end

      it 'returns true if the project merge_method is not rebase_merge or ff' do
        expect(project).to receive(:merge_method).and_return(:ff)
        expect(described_class.map_field(project, 'require_linear_history')).to be true
      end
    end

    describe '#restrict_push_merge_access?' do
      it 'returns true if all protected branches disallow force_push' do
        create(:protected_branch, project: project, allow_force_push: false)

        expect(described_class.map_field(project.reload, 'restrict_push_merge_access')).to be true
      end

      it 'returns false if any protected branbches allow force_push' do
        create(:protected_branch, project: project, allow_force_push: true)

        expect(described_class.map_field(project.reload, 'restrict_push_merge_access')).to be false
      end
    end

    describe '#force_push_disabled?' do
      it 'delegates to ProtectedBranch.allow_force_push?' do
        expect(ProtectedBranch).to receive(:allow_force_push?)
          .with(project, nil)

        described_class.map_field(project, 'force_push_disabled')
      end
    end

    describe 'terraform_enabled' do
      context 'when terraform states exist' do
        it 'returns true' do
          create(:terraform_state, project: project)

          expect(described_class.map_field(project, 'terraform_enabled')).to be true
        end
      end

      context 'when terraform states do not exist' do
        it 'returns false' do
          expect(described_class.map_field(project, 'terraform_enabled')).to be false
        end
      end
    end
  end
end
