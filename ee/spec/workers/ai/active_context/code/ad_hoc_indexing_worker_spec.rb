# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::AdHocIndexingWorker, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:connection) do
    create(:ai_active_context_connection, adapter_class: ActiveContext::Databases::Elasticsearch::Adapter)
  end

  let_it_be(:enabled_namespace) do
    create(
      :ai_active_context_code_enabled_namespace,
      namespace: project.namespace,
      connection_id: connection.id,
      state: :ready
    )
  end

  subject(:perform) { described_class.new.perform(project.id) }

  describe '#perform' do
    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'returns false and does not process' do
        expect { perform }.not_to change { Ai::ActiveContext::Code::Repository.count }
        expect(perform).to be false
      end
    end

    context 'when indexing is enabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      end

      context 'with invalid project_id' do
        subject(:perform) { described_class.new.perform(non_existing_record_id) }

        it 'returns false when project does not exist' do
          expect(perform).to be false
        end
      end

      context 'when project exists' do
        before do
          project.reload.project_setting.update!(duo_features_enabled: true)
        end

        context 'when project is not eligible for indexing' do
          context 'when duo_features_enabled is false' do
            before do
              project.reload.project_setting.update!(duo_features_enabled: false)
            end

            it 'returns false and does not create repository record' do
              expect { perform }.not_to change { Ai::ActiveContext::Code::Repository.count }
              expect(perform).to be false
            end
          end

          context 'when active_context_code_index_project feature flag is disabled' do
            before do
              stub_feature_flags(active_context_code_index_project: false)
            end

            it 'returns false and does not create repository record' do
              expect { perform }.not_to change { Ai::ActiveContext::Code::Repository.count }
              expect(perform).to be false
            end
          end
        end

        context 'when project is eligible for indexing' do
          before do
            stub_feature_flags(active_context_code_index_project: project)
          end

          context 'when no enabled namespace exists for the project' do
            before do
              enabled_namespace.destroy!
            end

            it 'returns false and does not create repository record' do
              expect { perform }.not_to change { Ai::ActiveContext::Code::Repository.count }
              expect(perform).to be false
            end
          end

          context 'when repository record already exists' do
            let!(:existing_repository) do
              create(:ai_active_context_code_repository,
                project: project, connection_id: connection.id, enabled_namespace: enabled_namespace)
            end

            it 'returns false and does not create duplicate repository record' do
              expect { perform }.not_to change { Ai::ActiveContext::Code::Repository.count }
              expect(perform).to be false
            end
          end

          context 'when repository record does not exist' do
            it 'creates repository record and enqueues RepositoryIndexWorker' do
              expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async)

              expect { perform }.to change { Ai::ActiveContext::Code::Repository.count }.by(1)

              repository = Ai::ActiveContext::Code::Repository.last
              expect(repository.project_id).to eq(project.id)
              expect(repository.enabled_namespace_id).to eq(enabled_namespace.id)
              expect(repository.connection_id).to eq(connection.id)
              expect(repository.state).to eq('pending')
            end

            it 'calls RepositoryIndexWorker with correct repository id' do
              expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async) do |repository_id|
                repository = Ai::ActiveContext::Code::Repository.find(repository_id)
                expect(repository.project_id).to eq(project.id)
              end

              perform
            end
          end
        end
      end

      it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

      it_behaves_like 'an idempotent worker' do
        let(:job_args) { [project.id] }
      end
    end
  end
end
