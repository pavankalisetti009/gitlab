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
        'scanner_iac_running'
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
  end
end
