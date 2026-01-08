# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::UpdateDefaultContextService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(project, user) }

  describe '#execute' do
    context 'when project has a default branch' do
      before do
        allow(project).to receive(:default_branch).and_return('main')
      end

      context 'when default tracked context does not exist' do
        it 'creates a new default tracked context' do
          expect { service.execute }.to change { Security::ProjectTrackedContext.count }.by(1)

          result = service.execute
          expect(result).to be_success

          tracked_context = result.payload[:tracked_context]
          expect(tracked_context.project).to eq(project)
          expect(tracked_context.context_name).to eq('main')
          expect(tracked_context.context_type).to eq('branch')
          expect(tracked_context.is_default).to be true
          expect(tracked_context).to be_tracked
        end
      end

      context 'when default tracked context exists with matching name' do
        let!(:existing_context) do
          create(:security_project_tracked_context,
            :default,
            project: project,
            context_name: 'main',
            context_type: :branch)
        end

        it 'does not update the context' do
          expect { service.execute }.not_to change { existing_context.reload.updated_at }

          result = service.execute
          expect(result).to be_success
          expect(result.payload[:tracked_context]).to eq(existing_context)
        end
      end

      context 'when default tracked context exists with different name' do
        let!(:existing_context) do
          create(:security_project_tracked_context,
            :default,
            project: project,
            context_name: 'master',
            context_type: :branch)
        end

        it 'updates the context name to match the default branch' do
          result = service.execute

          expect(result).to be_success
          expect(existing_context.reload.context_name).to eq('main')
          expect(result.payload[:tracked_context]).to eq(existing_context)
        end
      end

      context 'when update fails due to validation error' do
        let!(:existing_context) do
          create(:security_project_tracked_context,
            :default,
            project: project,
            context_name: 'master',
            context_type: :branch)
        end

        before do
          # Create a context with the target name to cause uniqueness validation error
          create(:security_project_tracked_context,
            :tracked,
            project: project,
            context_name: 'main',
            context_type: :branch,
            is_default: false)
        end

        it 'returns an error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to include('Context name has already been taken')
        end
      end
    end

    context 'when project does not have a default branch' do
      before do
        allow(project).to receive(:default_branch).and_return(nil)
      end

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Project does not have a default branch')
      end

      it 'does not create a tracked context' do
        expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
      end
    end
  end
end
