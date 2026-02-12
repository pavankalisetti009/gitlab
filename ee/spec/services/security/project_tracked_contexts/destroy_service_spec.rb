# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::DestroyService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:current_user) { user }
  let(:archive_vulnerabilities) { true }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe '#execute' do
    let!(:tracked_context) do
      create(:security_project_tracked_context, :tracked,
        project: project,
        context_name: 'feature-branch',
        context_type: :branch,
        is_default: false)
    end

    let(:service) do
      described_class.new(
        project: project,
        tracked_context_id: tracked_context.id,
        current_user: current_user,
        archive_vulnerabilities: archive_vulnerabilities
      )
    end

    subject(:result) { service.execute }

    it 'destroys tracked context successfully' do
      expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
      expect(result).to be_success
      expect(result.message).to eq('Tracked context removed')
    end

    context 'when destroy fails' do
      it 'handles ActiveRecord::RecordNotDestroyed exception' do
        mock_vulnerability_reads = instance_double(ActiveRecord::Associations::CollectionProxy)
        allow(mock_vulnerability_reads).to receive(:update_all).with(archived: true)

        mock_context = instance_double(Security::ProjectTrackedContext)
        allow(mock_context).to receive_messages(project_id: project.id, is_default?: false,
          vulnerability_reads: mock_vulnerability_reads)
        allow(mock_context).to receive(:destroy!).and_raise(
          ActiveRecord::RecordNotDestroyed.new("Validation failed")
        )

        allow_next_instance_of(described_class) do |service|
          allow(service).to receive(:find_tracked_context).and_return(mock_context)
        end

        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Failed to remove tracked context: Validation failed')
      end
    end

    context 'when tracked context has vulnerability reads' do
      let!(:vulnerability_read) do
        create(:vulnerability_read, project: project, security_project_tracked_context_id: tracked_context.id)
      end

      context 'when archive_vulnerabilities is true' do
        it 'archives vulnerabilities and destroys context' do
          expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
          expect(result).to be_success

          vulnerability_read.reload
          expect(vulnerability_read.archived).to be true
        end
      end

      context 'when archive_vulnerabilities is false' do
        let(:archive_vulnerabilities) { false }

        it 'destroys context without archiving vulnerabilities' do
          expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
          expect(result).to be_success

          vulnerability_read.reload
          expect(vulnerability_read.archived).to be_falsy
        end
      end
    end

    context 'when trying to untrack default branch' do
      let!(:tracked_context) do
        create(:security_project_tracked_context, :tracked,
          project: project,
          context_name: project.default_branch,
          context_type: :branch,
          is_default: true)
      end

      it 'prevents untracking' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Cannot untrack default branch')
      end
    end

    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it 'allows internal usage' do
        expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
        expect(result).to be_success
      end
    end

    context 'when tracked context does not exist' do
      let(:service) do
        described_class.new(
          project: project,
          tracked_context_id: non_existing_record_id,
          current_user: current_user,
          archive_vulnerabilities: archive_vulnerabilities
        )
      end

      it 'returns not found error' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Tracked context not found')
      end
    end

    context 'when tracked context belongs to different project' do
      let!(:other_project) { create(:project, :repository) }
      let!(:other_tracked_context) do
        create(:security_project_tracked_context, :tracked,
          project: other_project,
          context_name: 'other-branch',
          context_type: :branch,
          is_default: false)
      end

      let(:service) do
        described_class.new(
          project: project,
          tracked_context_id: other_tracked_context.id,
          current_user: current_user,
          archive_vulnerabilities: archive_vulnerabilities
        )
      end

      it 'returns project mismatch error' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Tracked ref does not belong to specified project')
      end
    end
  end
end
