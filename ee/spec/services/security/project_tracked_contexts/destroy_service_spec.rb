# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::DestroyService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:guest_user) { create(:user) }

  let(:current_user) { user }

  before_all do
    project.add_maintainer(user)
    project.add_guest(guest_user)
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

    let(:service) { described_class.new(tracked_context, current_user) }

    subject(:result) { service.execute }

    context 'when user has permission' do
      it 'destroys tracked context successfully' do
        expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
        expect(result).to be_success
        expect(result.message).to eq('Tracked context removed')
      end

      context 'when tracked context has vulnerability reads' do
        let!(:vulnerability_read) do
          create(:vulnerability_read, project: project, security_project_tracked_context_id: tracked_context.id)
        end

        it 'destroys context with vulnerability reads' do
          expect { result }.to change { Security::ProjectTrackedContext.count }.by(-1)
          expect(result).to be_success
        end
      end

      context 'when trying to delete default branch tracking' do
        let!(:tracked_context) do
          create(:security_project_tracked_context, :tracked,
            project: project,
            context_name: project.default_branch,
            context_type: :branch,
            is_default: true)
        end

        it 'prevents deletion' do
          expect { result }.not_to change { Security::ProjectTrackedContext.count }
          expect(result).to be_error
          expect(result.message).to eq('Cannot delete default branch tracking')
        end
      end
    end

    context 'when user lacks permission' do
      let(:current_user) { guest_user }

      it 'denies access' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
        expect(result).to be_error
        expect(result.message).to eq('Permission denied')
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
        expect(result.message).to eq('Tracked context not found')
      end
    end

    context 'when tracked context is already destroyed' do
      it 'returns not found error' do
        tracked_context.destroy!

        expect(result).to be_error
        expect(result.message).to eq('Tracked context not found')
      end
    end
  end
end
