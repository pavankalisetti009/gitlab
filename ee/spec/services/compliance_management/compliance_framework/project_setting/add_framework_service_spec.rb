# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectSetting::AddFrameworkService, feature_category: :compliance_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:framework) { create(:compliance_framework) }
  let_it_be(:current_user) { create(:user) }

  let(:service) { described_class.new(project_id: project.id, current_user: current_user, framework: framework) }

  describe '#execute' do
    context 'when the project setting does not exist' do
      it 'creates a new project setting record' do
        expect { service.execute }.to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }.by(1)
      end

      it 'creates the project setting with the correct attributes' do
        service.execute

        setting = ComplianceManagement::ComplianceFramework::ProjectSettings.last
        expect(setting.project_id).to eq(project.id)
        expect(setting.framework_id).to eq(framework.id)
      end

      it 'returns a successful service response' do
        expect(service.execute.success?).to be true
      end

      it 'publishes a compliance framework changed event' do
        expect(::Gitlab::EventStore).to receive(:publish).with(
          an_instance_of(::Projects::ComplianceFrameworkChangedEvent)
        ).and_call_original

        service.execute
      end

      it 'creates an audit event' do
        expect { service.execute }.to change { AuditEvent.count }.by(1)
      end
    end

    context 'when the project setting already exists' do
      before do
        create(:compliance_framework_project_setting,
          project_id: project.id,
          compliance_management_framework: framework)
      end

      it 'does not create a new project setting record' do
        expect { service.execute }.not_to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }
      end

      it 'returns a successful service response' do
        expect(service.execute.success?).to be true
      end

      it 'does not publish a compliance framework changed event' do
        expect(::Gitlab::EventStore).not_to receive(:publish)

        service.execute
      end

      it 'does not create an audit event' do
        expect { service.execute }.not_to change { AuditEvent.count }
      end
    end

    context 'when the project setting cannot be created' do
      before do
        allow(framework.projects).to receive(:push).with(project).and_return(false)
      end

      it 'returns an error service response' do
        response = service.execute

        expect(response.success?).to be false
        expect(response.message).to include("Failed to assign the framework to project")
      end

      it 'does not publish an event' do
        expect(::Gitlab::EventStore).not_to receive(:publish)

        service.execute
      end

      it 'does not create an audit event' do
        expect { service.execute }.not_to change { AuditEvent.count }
      end
    end

    context 'when the project does not exist' do
      let(:project_id) { non_existing_record_id }
      let(:service) { described_class.new(project_id: project_id, current_user: current_user, framework: framework) }

      it 'returns an error service response' do
        response = service.execute

        expect(response.success?).to be false
        expect(response.message).to include("Project not found")
      end
    end
  end
end
