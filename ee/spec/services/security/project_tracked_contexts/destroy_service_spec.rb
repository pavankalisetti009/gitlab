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
        tracked_context: tracked_context,
        current_user: current_user,
        archive_vulnerabilities: archive_vulnerabilities
      )
    end

    subject(:result) { service.execute }

    it 'destroys tracked context successfully' do
      expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
      expect(result).to be_success
      expect(result.message).to eq('Tracked context removed')
      expect(result.payload[:destroyed_context]).to be_present
      expect(result.payload[:destroyed_context].context_name).to eq('feature-branch')
    end

    context 'when destroy fails' do
      it 'handles ActiveRecord::RecordNotDestroyed exception' do
        allow(tracked_context).to receive(:destroy!).and_raise(
          ActiveRecord::RecordNotDestroyed.new("Validation failed")
        )

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

    context 'when tracked context is nil' do
      let(:tracked_context) { nil }

      it 'returns not found error' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Ref not found')
      end
    end

    context 'when tracked context is already destroyed' do
      it 'returns not found error' do
        tracked_context.destroy!

        expect(result).to be_error
        expect(result.message).to eq('Ref not found')
      end
    end
  end
end
