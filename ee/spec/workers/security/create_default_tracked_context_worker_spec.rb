# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::CreateDefaultTrackedContextWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  let(:event) do
    Projects::ProjectCreatedEvent.new(data: {
      project_id: project.id,
      namespace_id: project.namespace_id,
      root_namespace_id: project.root_namespace.id
    })
  end

  include_examples 'an idempotent worker' do
    let(:job_args) { [event] }
  end

  describe '#handle_event' do
    subject(:handle_event) { described_class.new.handle_event(event) }

    context 'when project exists' do
      it 'creates a default tracked context for the project default branch' do
        expect { handle_event }.to change { Security::ProjectTrackedContext.count }.by(1)

        tracked_context = Security::ProjectTrackedContext.last
        expect(tracked_context.project).to eq(project)
        expect(tracked_context.context_name).to eq(project.default_branch_or_main)
        expect(tracked_context.context_type).to eq('branch')
        expect(tracked_context.is_default).to be true
        expect(tracked_context).to be_tracked
      end

      it 'calls the CreateService with correct parameters' do
        expect(Security::ProjectTrackedContexts::CreateService).to receive(:new).with(
          project,
          nil,
          {
            context_name: project.default_branch_or_main,
            context_type: :branch,
            is_default: true,
            track: true
          }
        ).and_call_original

        handle_event
      end

      context 'when project has a custom default branch' do
        before do
          allow(Gitlab::DefaultBranch).to receive(:value).and_return('develop')
        end

        it 'uses the custom default branch name' do
          handle_event

          tracked_context = Security::ProjectTrackedContext.last
          expect(tracked_context.context_name).to eq('develop')
        end
      end

      context 'when CreateService returns success' do
        it 'does not log any warnings' do
          expect(Gitlab::AppLogger).not_to receive(:warn)

          handle_event
        end
      end

      context 'when CreateService returns error' do
        let(:service_result) do
          ServiceResponse.error(
            message: 'Some error',
            payload: {
              tracked_context: build(:security_project_tracked_context)
            }
          )
        end

        before do
          allow_next_instance_of(Security::ProjectTrackedContexts::CreateService) do |service|
            allow(service).to receive(:execute).and_return(service_result)
          end
        end

        it 'logs a warning about quota limit' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            message: "Failed to create default tracked context for project: Some error",
            project_id: project.id,
            project_path: project.full_path
          )

          handle_event
        end
      end

      it 'does not create duplicate default tracked contexts if ran twice' do
        2.times { handle_event }
        expect(Security::ProjectTrackedContext.count).to eq(1)
      end
    end

    context 'when project does not exist' do
      let(:event) do
        Projects::ProjectCreatedEvent.new(data: {
          project_id: non_existing_record_id,
          namespace_id: project.namespace_id,
          root_namespace_id: project.root_namespace.id
        })
      end

      it 'does not create any tracked context' do
        expect { handle_event }.not_to change { Security::ProjectTrackedContext.count }
      end

      it 'does not raise an error' do
        expect { handle_event }.not_to raise_error
      end

      it 'does not call CreateService' do
        expect(Security::ProjectTrackedContexts::CreateService).not_to receive(:new)

        handle_event
      end
    end
  end

  describe 'event subscription' do
    it 'is subscribed to ProjectCreatedEvent' do
      expect(described_class.ancestors).to include(Gitlab::EventStore::Subscriber)
    end
  end
end
