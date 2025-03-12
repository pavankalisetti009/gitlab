# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService,
  feature_category: :compliance_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework))
  end

  let_it_be(:control) do
    create(:compliance_requirements_control,
      compliance_requirement: requirement,
      control_type: :external,
      external_url: 'https://example.com',
      secret_token: 'foo')
  end

  let_it_be(:project_control_compliance_status) do
    create(:project_control_compliance_status,
      project: project,
      compliance_requirements_control: control,
      compliance_requirement: requirement,
      status: 'pending')
  end

  let_it_be(:user) { create(:user) }

  subject(:service) do
    described_class.new(current_user: user, control: control, project: project, status_value: 'pass')
  end

  context 'when feature is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    it 'returns an error' do
      result = service.execute

      expect(result.success?).to be false
      expect(result.message).to eq(
        _('Failed to update compliance control status. Error: Not permitted to update compliance control status')
      )
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when status is valid' do
      it 'updates the compliance requirement control status' do
        expect { service.execute }.to change { project_control_compliance_status.reload.status }.to('pass')
      end

      it 'is successful' do
        result = service.execute

        expect(result.success?).to be true
        expect(result.payload[:status]).to eq('pass')
      end

      it 'audits the changes' do
        service.execute

        expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'compliance_control_status_pass',
          scope: project,
          target: project_control_compliance_status,
          message: "Changed compliance control status from 'pending' to 'pass'",
          author: user
        )
      end

      context 'when project control status does not exist' do
        before do
          project_control_compliance_status.destroy!
        end

        it 'creates a new project control compliance status' do
          expect { service.execute }.to change {
            ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.count
          }.by(1)
        end

        it 'sets the correct attributes' do
          service.execute

          new_status = ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus.last
          expect(new_status.status).to eq('pass')
          expect(new_status.project_id).to eq(project.id)
          expect(new_status.compliance_requirements_control_id).to eq(control.id)
        end
      end
    end

    context 'with invalid params' do
      shared_examples 'rejects invalid status' do |status|
        let(:service) do
          described_class.new(current_user: user, control: control, project: project, status_value: status)
        end

        it "does not update project control compliance status" do
          expect { service.execute }.not_to change { project_control_compliance_status.reload.attributes }
        end

        it "is unsuccessful" do
          result = service.execute

          expect(result.success?).to be false
          expect(result.message).to eq(
            "Failed to update compliance control status. Error: '#{status}' is not a valid status"
          )
        end

        it "does not audit the changes" do
          service.execute

          expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
        end
      end

      it_behaves_like 'rejects invalid status', 'pending'
      it_behaves_like 'rejects invalid status', 'invalid'
    end

    context 'when status update fails' do
      before do
        # Stub the existing status record to fail on update
        allow(project_control_compliance_status).to receive_messages(update: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Some validation error']))

        # Ensure create_or_find_for_project_and_control returns our stubbed instance
        allow(ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus)
          .to receive(:create_or_find_for_project_and_control)
          .with(project, control)
          .and_return(project_control_compliance_status)
      end

      it 'returns an error with validation messages' do
        result = service.execute

        expect(result.success?).to be false
        expect(result.message).to eq(
          'Failed to update compliance control status. Error: Some validation error'
        )
      end

      it 'does not audit the changes' do
        service.execute

        expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
      end
    end
  end
end
