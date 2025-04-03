# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MarkForDeletionService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:project) do
    create(:project, :repository, namespace: user.namespace)
  end

  subject(:result) { described_class.new(project, user).execute }

  def execute_send_project_deletion_notification
    service = described_class.new(project, user)
    service.send(:send_project_deletion_notification)
  end

  context 'when the delayed delete feature is licensed' do
    before do
      stub_licensed_features(
        adjourned_deletion_for_projects_and_groups: true,
        security_orchestration_policies: true)
    end

    it 'does not hide the project', :aggregate_failures do
      expect(result[:status]).to eq(:success)
      expect(project).not_to be_hidden
    end

    context 'when the delayed delete feature is not licensed for the project' do
      before do
        allow(project).to receive(:licensed_feature_available?).and_return(false)
      end

      context 'when the downtier_delayed_deletion feature flag is enabled' do
        it 'does not hide the project', :aggregate_failures do
          expect(result[:status]).to eq(:success)
          expect(project).not_to be_hidden
        end
      end

      context 'when the downtier_delayed_deletion feature flag is disabled' do
        before do
          stub_feature_flags(downtier_delayed_deletion: false)
        end

        it 'hides the project', :aggregate_failures do
          expect(result[:status]).to eq(:success)
          expect(project).to be_hidden
        end
      end
    end

    context 'when marking project for deletion once again' do
      let(:marked_for_deletion_at) { 2.days.ago }

      it 'does not change original date', :freeze_time, :aggregate_failures do
        project.update!(marked_for_deletion_at: marked_for_deletion_at)

        expect(result[:status]).to eq(:success)
        expect(project.marked_for_deletion_at).to eq(marked_for_deletion_at.to_date)
      end
    end

    context 'when attempting to mark security policy project for deletion' do
      before do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: project)
      end

      it 'errors' do
        expect(result).to eq(
          status: :error,
          message: 'Project cannot be deleted because it is linked as a security policy project')
      end

      it "doesn't mark the project for deletion" do
        expect { result }.not_to change { project.marked_for_deletion? }.from(false)
      end

      it 'does not send notification email' do
        stub_feature_flags(project_deletion_notification_email: true)

        expect(NotificationService).not_to receive(:new)

        result
      end

      context 'without licensed feature' do
        before do
          stub_licensed_features(
            adjourned_deletion_for_projects_and_groups: true,
            security_orchestration_policies: false)
        end

        it 'marks the project for deletion' do
          expect { result }.to change { project.marked_for_deletion? }.from(false).to(true)
        end
      end
    end

    context 'for audit events' do
      it 'saves audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'project_path_updated')
        ).and_call_original

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'project_name_updated')
        ).and_call_original

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'project_deletion_marked')
        ).and_call_original

        expect { result }.to change { AuditEvent.count }.by(3)
      end
    end

    it 'calls send_project_deletion_notification method when successful' do
      service = described_class.new(project, user)

      expect(service).to receive(:send_project_deletion_notification)

      service.execute
    end
  end

  context 'when delayed deletion is not licensed' do
    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      stub_feature_flags(downtier_delayed_deletion: false)
    end

    it 'returns an error' do
      expect(result).to eq({ status: :error, message: 'Cannot mark project for deletion: feature not supported' })
    end
  end

  describe '#send_project_deletion_notification' do
    context 'when all conditions are met' do
      before do
        stub_feature_flags(project_deletion_notification_email: true)
        allow(project).to receive_messages(adjourned_deletion?: true, marked_for_deletion?: true)
      end

      it 'sends a notification email' do
        expect_next_instance_of(NotificationService) do |service|
          expect(service).to receive(:project_scheduled_for_deletion).with(project)
        end

        execute_send_project_deletion_notification
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(project_deletion_notification_email: false)
        allow(project).to receive_messages(adjourned_deletion?: true, marked_for_deletion?: true)
      end

      it 'does not send a notification email' do
        expect(NotificationService).not_to receive(:new)

        execute_send_project_deletion_notification
      end
    end

    context 'when feature flag is enabled for specific project' do
      before do
        stub_feature_flags(project_deletion_notification_email: project)
        allow(project).to receive_messages(adjourned_deletion?: true, marked_for_deletion?: true)
      end

      it 'sends a notification email' do
        expect_next_instance_of(NotificationService) do |service|
          expect(service).to receive(:project_scheduled_for_deletion).with(project)
        end

        execute_send_project_deletion_notification
      end
    end

    context 'when adjourned deletion is disabled' do
      before do
        stub_feature_flags(project_deletion_notification_email: true)
        allow(project).to receive_messages(adjourned_deletion?: false, marked_for_deletion?: true)
      end

      it 'does not send a notification email' do
        expect(NotificationService).not_to receive(:new)

        execute_send_project_deletion_notification
      end
    end

    context 'when project is not marked for deletion' do
      before do
        stub_feature_flags(project_deletion_notification_email: true)
        allow(project).to receive_messages(adjourned_deletion?: true, marked_for_deletion?: false)
      end

      it 'does not send a notification email' do
        expect(NotificationService).not_to receive(:new)

        execute_send_project_deletion_notification
      end
    end
  end
end
