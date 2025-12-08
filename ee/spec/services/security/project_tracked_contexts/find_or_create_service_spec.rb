# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::FindOrCreateService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }

  let(:context_name) { 'main' }
  let(:context_type) { :branch }
  let(:is_default) { true }

  let(:params) do
    {
      project: project,
      context_name: context_name,
      context_type: context_type,
      is_default: is_default
    }
  end

  subject(:service) { described_class.new(**params) }

  describe '.from_pipeline' do
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

    subject(:service) { described_class.from_pipeline(pipeline) }

    context 'when pipeline is for a branch' do
      it 'initializes service with correct branch parameters' do
        expect(service.project).to eq(project)
        expect(service.context_name).to eq('feature-branch')
        expect(service.context_type).to eq(:branch)
        expect(service.is_default).to be false
      end
    end

    context 'when pipeline is for a tag' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'v1.0.0', tag: true) }

      it 'initializes service with correct tag parameters' do
        expect(service.project).to eq(project)
        expect(service.context_name).to eq('v1.0.0')
        expect(service.context_type).to eq(:tag)
        expect(service.is_default).to be false
      end
    end

    context 'when pipeline is for the default branch' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }

      it 'sets is_default to true' do
        expect(service.is_default).to be true
      end
    end
  end

  describe '#execute' do
    subject(:result) { service.execute }

    context 'when tracked context already exists' do
      let_it_be(:existing_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: 'main',
          context_type: :branch)
      end

      it 'returns success with the existing context' do
        expect(result).to be_success
        expect(result.payload[:tracked_context]).to eq(existing_context)
      end

      it 'does not create a new tracked context' do
        expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
      end

      it 'does not update the existing context' do
        original_state = existing_context.state

        service.execute

        expect(existing_context.reload.state).to eq(original_state)
      end

      context 'when context is not tracked' do
        before do
          existing_context.untrack!
        end

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Context is not tracked')
        end
      end
    end

    context 'when tracked context does not exist' do
      context 'when is_default is true' do
        let(:is_default) { true }

        it 'creates a new tracked context' do
          expect { service.execute }.to change { Security::ProjectTrackedContext.count }.by(1)
        end

        it 'returns success with the created context' do
          expect(result).to be_success
          tracked_context = result.payload[:tracked_context]
          expect(tracked_context).to be_persisted
          expect(tracked_context.project).to eq(project)
          expect(tracked_context.context_name).to eq(context_name)
          expect(tracked_context.context_type).to eq(context_type.to_s)
          expect(tracked_context.state).to eq(Security::ProjectTrackedContext::STATES[:tracked])
          expect(tracked_context.is_default).to be true
        end

        context 'when creation fails due to validation errors' do
          let(:context_name) { nil }

          it 'returns an error' do
            expect(result).to be_error
            expect(result.message).to include("Context name can't be blank")
          end

          it 'does not create a tracked context' do
            expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
          end
        end

        context 'when tracked refs limit is exceeded' do
          let(:max_refs) { 1 }

          before do
            stub_const('Security::ProjectTrackedContext::MAX_TRACKED_REFS_PER_PROJECT', max_refs)
            create(:security_project_tracked_context, :tracked, project: project)
          end

          it 'returns an error' do
            expect(result).to be_error
            expect(result.message).to include("cannot exceed #{max_refs} tracked refs per project")
          end

          it 'does not create a tracked context' do
            expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
          end
        end
      end

      context 'when is_default is false' do
        let(:is_default) { false }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Expected context to already exist for non-default branches')
        end

        it 'does not create a tracked context' do
          expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
        end
      end

      context 'when is_default is nil' do
        let(:is_default) { nil }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Expected context to already exist for non-default branches')
        end

        it 'does not create a tracked context' do
          expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
        end
      end
    end

    context 'when finding existing context by different attributes' do
      let_it_be(:branch_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: 'develop',
          context_type: :branch)
      end

      let_it_be(:tag_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: 'develop',
          context_type: :tag)
      end

      context 'when searching for a branch context' do
        let(:context_name) { 'develop' }
        let(:context_type) { :branch }

        it 'finds the branch context, not the tag context' do
          expect(result).to be_success
          expect(result.payload[:tracked_context]).to eq(branch_context)
        end
      end

      context 'when searching for a tag context' do
        let(:context_name) { 'develop' }
        let(:context_type) { :tag }

        it 'finds the tag context, not the branch context' do
          expect(result).to be_success
          expect(result.payload[:tracked_context]).to eq(tag_context)
        end
      end
    end

    context 'when multiple projects have contexts with the same name' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_project_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: other_project,
          context_name: 'main',
          context_type: :branch)
      end

      it 'only finds contexts for the specified project' do
        expect(result).to be_success
        tracked_context = result.payload[:tracked_context]
        expect(tracked_context).to be_persisted
        expect(tracked_context.project).to eq(project)
        expect(tracked_context).not_to eq(other_project_context)
      end
    end
  end
end
