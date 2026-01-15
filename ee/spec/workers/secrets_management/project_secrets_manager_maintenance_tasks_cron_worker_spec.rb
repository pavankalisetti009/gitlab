# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagerMaintenanceTasksCronWorker, feature_category: :secrets_management do
  let(:worker) { described_class.new }
  let(:deprovision_worker_spy) { class_spy(SecretsManagement::DeprovisionProjectSecretsManagerWorker) }

  before do
    stub_const('SecretsManagement::DeprovisionProjectSecretsManagerWorker', deprovision_worker_spy)
  end

  describe '#perform' do
    subject(:run_worker) { worker.perform }

    context 'when there are stale tasks' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project_secrets_manager) { create(:project_secrets_manager) }

      let!(:stale_task) do
        create(:project_secrets_manager_maintenance_task,
          :stale,
          user: user,
          project_secrets_manager: project_secrets_manager)
      end

      it 'recovers stale tasks and re-enqueues worker' do
        expect { run_worker }.to change { stale_task.reload.retry_count }.by(1)

        expect(deprovision_worker_spy).to have_received(:perform_async)
          .with(user.id, project_secrets_manager.id)
      end

      it 'updates last_processed_at timestamp' do
        freeze_time do
          run_worker

          expect(stale_task.reload.last_processed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs recovery warning' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: "Retrying failed secrets_manager maintenance task",
            task_id: stale_task.id,
            retry_count: 0
          )
        )

        run_worker
      end
    end

    context 'when there are no stale tasks' do
      it 'does not enqueue any workers' do
        run_worker

        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when task has reached max retries' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project_secrets_manager) { create(:project_secrets_manager) }

      let!(:max_retried_task) do
        create(:project_secrets_manager_maintenance_task,
          :stale,
          user: user,
          project_secrets_manager: project_secrets_manager,
          retry_count: described_class::MAX_RETRIES)
      end

      it 'does not process the task' do
        expect { run_worker }.not_to change { max_retried_task.reload.retry_count }

        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when processing multiple stale tasks' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project_secrets_manager1) { create(:project_secrets_manager) }
      let_it_be(:project_secrets_manager2) { create(:project_secrets_manager) }

      let!(:stale_task1) do
        create(:project_secrets_manager_maintenance_task,
          :stale,
          user: user,
          project_secrets_manager: project_secrets_manager1)
      end

      let!(:stale_task2) do
        create(:project_secrets_manager_maintenance_task,
          :stale,
          user: user,
          project_secrets_manager: project_secrets_manager2)
      end

      it 'processes all stale tasks' do
        run_worker

        expect(deprovision_worker_spy).to have_received(:perform_async).twice
        expect(deprovision_worker_spy).to have_received(:perform_async)
          .with(user.id, project_secrets_manager1.id)
        expect(deprovision_worker_spy).to have_received(:perform_async)
          .with(user.id, project_secrets_manager2.id)
      end
    end

    context 'when task is processing but not stale yet' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project_secrets_manager) { create(:project_secrets_manager) }

      let!(:processing_task) do
        create(:project_secrets_manager_maintenance_task,
          :processing,
          user: user,
          project_secrets_manager: project_secrets_manager)
      end

      it 'does not process the task' do
        run_worker

        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end
  end

  it_behaves_like 'an idempotent worker'
end
