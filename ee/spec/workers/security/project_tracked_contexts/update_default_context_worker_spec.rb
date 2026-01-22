# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::UpdateDefaultContextWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }

  describe '#handle_event' do
    shared_examples 'updates default tracked context' do
      let(:event) do
        event_class.new(data: {
          container_id: project.id,
          container_type: 'Project'
        })
      end

      subject(:handle_event) { described_class.new.handle_event(event) }

      context 'when update_default_security_tracked_contexts_worker FF is enabled' do
        before do
          stub_feature_flags(update_default_security_tracked_contexts_worker: true)
        end

        context 'when project exists' do
          before do
            allow(project).to receive(:default_branch).and_return('main')
          end

          it 'calls UpdateDefaultService' do
            expect(Security::ProjectTrackedContexts::UpdateDefaultContextService)
              .to receive(:new).with(project).and_call_original

            handle_event
          end

          context 'when UpdateDefaultService succeeds' do
            it 'does not log any warnings' do
              expect(Gitlab::AppLogger).not_to receive(:warn)

              handle_event
            end
          end

          context 'when UpdateDefaultService fails' do
            let(:service_result) do
              ServiceResponse.error(
                message: 'Some error',
                payload: {
                  tracked_context: build(:security_project_tracked_context)
                }
              )
            end

            before do
              allow_next_instance_of(Security::ProjectTrackedContexts::UpdateDefaultContextService) do |service|
                allow(service).to receive(:execute).and_return(service_result)
              end
            end

            it 'logs a warning' do
              expect(Gitlab::AppLogger).to receive(:warn).with(
                message: "Failed to update default tracked context for project: Some error",
                project_id: project.id,
                project_path: project.full_path
              )

              handle_event
            end
          end
        end

        context 'when project does not exist' do
          let(:event) do
            event_class.new(data: {
              container_id: non_existing_record_id,
              container_type: 'Project'
            })
          end

          it 'does not raise an error' do
            expect { handle_event }.not_to raise_error
          end

          it 'does not call UpdateDefaultService' do
            expect(Security::ProjectTrackedContexts::UpdateDefaultContextService).not_to receive(:new)

            handle_event
          end
        end
      end

      context 'when update_default_security_tracked_contexts_worker FF is disabled' do
        before do
          stub_feature_flags(update_default_security_tracked_contexts_worker: false)
        end

        context 'when project exists' do
          before do
            allow(project).to receive(:default_branch).and_return('main')
          end

          it 'does not call UpdateDefaultService' do
            expect(Security::ProjectTrackedContexts::UpdateDefaultContextService).not_to receive(:new)

            handle_event
          end
        end

        context 'when project does not exist' do
          let(:event) do
            event_class.new(data: {
              container_id: non_existing_record_id,
              container_type: 'Project'
            })
          end

          it 'does not raise an error' do
            expect { handle_event }.not_to raise_error
          end

          it 'does not call UpdateDefaultService' do
            expect(Security::ProjectTrackedContexts::UpdateDefaultContextService).not_to receive(:new)

            handle_event
          end
        end
      end

      context 'when container_type is not Project' do
        let(:event) do
          event_class.new(data: {
            container_id: project.id,
            container_type: 'Snippet'
          })
        end

        it 'does not call UpdateDefaultService' do
          expect(Security::ProjectTrackedContexts::UpdateDefaultContextService).not_to receive(:new)

          handle_event
        end
      end

      include_examples 'an idempotent worker' do
        let(:job_args) { [event] }
      end
    end

    context 'when handling DefaultBranchChangedEvent' do
      let(:event_class) { Repositories::DefaultBranchChangedEvent }

      it_behaves_like 'updates default tracked context'
    end

    context 'when handling RepositoryCreatedEvent' do
      let(:event_class) { Repositories::RepositoryCreatedEvent }

      it_behaves_like 'updates default tracked context'
    end
  end
end
