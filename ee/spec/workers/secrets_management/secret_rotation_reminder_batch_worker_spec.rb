# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretRotationReminderBatchWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  include EmailHelpers
  include NotificationHelpers

  let(:service_class) { SecretsManagement::SecretRotationBatchReminderService }

  before do
    stub_const("#{service_class}::BATCH_SIZE", 2)
  end

  describe '#perform' do
    let(:worker) { described_class.new }

    subject(:run_worker) { worker.perform }

    it 'continues processing until processed_count is less than batch size' do
      expect_next_instance_of(service_class) do |service|
        expect(service).to receive(:execute)
          .exactly(3).times
          .and_return(
            { processed_count: 2, skipped_count: 0 },  # Full batch - continue
            { processed_count: 2, skipped_count: 1 },  # Full batch - continue
            { processed_count: 1, skipped_count: 1 }   # stop
          )
      end

      expect(worker).to receive(:log_extra_metadata_on_done)
        .with(:result, {
          status: :completed,
          processed_secrets: 5,
          skipped_secrets: 2
        })

      run_worker
    end

    context 'when runtime limit is exceeded' do
      it 'stops processing even with full batches and logs limit_reached status' do
        # Stub the service to return full batches
        expect_next_instance_of(service_class) do |service|
          expect(service).to receive(:execute).and_return({
            processed_count: 2, # Full batch size
            skipped_count: 0
          })
        end

        # Mock RuntimeLimiter to return true on over_time? check
        expect_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
          allow(runtime_limiter).to receive(:over_time?).and_return(true)
        end

        expect(worker).to receive(:log_extra_metadata_on_done)
          .with(:result, {
            status: :limit_reached,
            processed_secrets: 2,
            skipped_secrets: 0
          })

        run_worker
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let_it_be(:project) { create(:project) }
    let_it_be(:owner) { create(:user, owner_of: project) }

    let(:secrets_manager) { create(:project_secrets_manager, project: project) }
    let(:rotation_infos) { SecretsManagement::SecretRotationInfo.all }

    it 'processes all pending reminders when called multiple times' do
      provision_project_secrets_manager(secrets_manager, owner)
      reset_delivered_emails!

      # Create secrets that are due for reminder by now
      create_project_secret(
        user: owner,
        project: project,
        name: 'SECRET_1',
        description: 'test secret 1',
        value: 'value1',
        branch: '*',
        environment: '*',
        rotation_interval_days: 30
      ).tap do |secret|
        secret.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      end

      create_project_secret(
        user: owner,
        project: project,
        name: 'SECRET_2',
        description: 'test secret 2',
        value: 'value2',
        branch: '*',
        environment: '*',
        rotation_interval_days: 20
      ).tap do |secret|
        secret.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      end

      create_project_secret(
        user: owner,
        project: project,
        name: 'SECRET_3',
        description: 'test secret 3',
        value: 'value3',
        branch: '*',
        environment: '*',
        rotation_interval_days: 30
      ).tap do |secret|
        secret.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      end

      # Validate current timestamps
      rotation_infos.each do |rotation_info|
        expect(rotation_info.last_reminder_at).to be_nil
        expect(rotation_info.next_reminder_at).to be_past
      end

      # This will call perform twice
      perform_idempotent_work

      expect_enqueud_email(owner.id, project.id, 'SECRET_1', mail: "secret_rotation_reminder_email")
      expect_enqueud_email(owner.id, project.id, 'SECRET_2', mail: "secret_rotation_reminder_email")
      expect_enqueud_email(owner.id, project.id, 'SECRET_3', mail: "secret_rotation_reminder_email")

      # All reminders should be processed and have timestamps updated
      rotation_infos.each do |rotation_info|
        rotation_info.reload
        expect(rotation_info.last_reminder_at).to be_present
        expect(rotation_info.next_reminder_at).to be_future
      end
    end
  end
end
