# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MarkForDeletionService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:project) do
    create(:project, :repository, namespace: user.namespace)
  end

  subject(:result) { described_class.new(project, user).execute }

  context 'when attempting to mark security policy project for deletion' do
    before do
      stub_licensed_features(security_orchestration_policies: true)
      create(:security_orchestration_policy_configuration, security_policy_management_project: project)
    end

    it 'errors' do
      expect(result).to be_error
      expect(result.message).to eq('Project cannot be deleted because it is linked as a security policy project')
    end

    it "doesn't mark the project for deletion" do
      expect { result }.not_to change { project.self_deletion_scheduled? }.from(false)
    end

    context 'without licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'marks the project for deletion' do
        expect { result }.to change { project.self_deletion_scheduled? }.from(false).to(true)
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
end
