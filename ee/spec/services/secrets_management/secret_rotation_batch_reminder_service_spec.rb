# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretRotationBatchReminderService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include EmailHelpers
  include NotificationHelpers

  let_it_be_with_reload(:project1) { create(:project) }
  let_it_be_with_reload(:project2) { create(:project) }
  let_it_be(:owner1) { project1.owner }
  let_it_be(:owner2) { project2.owner }

  let!(:secrets_manager1) { create(:project_secrets_manager, project: project1) }
  let!(:secrets_manager2) { create(:project_secrets_manager, project: project2) }

  let(:service) { described_class.new }

  before do
    provision_project_secrets_manager(secrets_manager1, owner1)
    provision_project_secrets_manager(secrets_manager2, owner2)
    reset_delivered_emails!
  end

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    let!(:secret_1) do
      create_project_secret(
        user: owner1,
        project: project1,
        name: 'SECRET_1',
        description: 'test secret 1',
        value: 'value1',
        branch: '*',
        environment: '*',
        rotation_interval_days: 30
      )
    end

    let!(:secret_2) do
      create_project_secret(
        user: owner2,
        project: project2,
        name: 'SECRET_2',
        description: 'test secret 2',
        value: 'value2',
        branch: '*',
        environment: '*',
        rotation_interval_days: 20
      )
    end

    let!(:secret_3) do
      create_project_secret(
        user: owner1,
        project: project1,
        name: 'SECRET_3',
        description: 'test secret 3',
        value: 'value3',
        branch: '*',
        environment: '*',
        rotation_interval_days: 20
      )
    end

    context 'when there are no secrets needing reminders' do
      it 'returns zero processed count' do
        expect(result).to eq(processed_count: 0, skipped_count: 0)

        expect_no_delivery_jobs
      end
    end

    context 'when there are secrets needing reminders' do
      before do
        # Make 2 of the secrets eligible for reminders
        secret_1.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
        secret_2.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
      end

      it 'processes all eligible secrets' do
        expect(result).to eq(processed_count: 2, skipped_count: 0)

        expect_delivery_jobs_count(2)
        expect_enqueud_email(owner1.id, project1.id, 'SECRET_1', mail: "secret_rotation_reminder_email")
        expect_enqueud_email(owner2.id, project2.id, 'SECRET_2', mail: "secret_rotation_reminder_email")

        secret_1.rotation_info.reload
        secret_2.rotation_info.reload

        expect(secret_1.rotation_info.last_reminder_at).to be_present
        expect(secret_1.rotation_info.next_reminder_at).to be_future
        expect(secret_2.rotation_info.last_reminder_at).to be_present
        expect(secret_2.rotation_info.next_reminder_at).to be_future
      end

      context 'with batch size limit' do
        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)
        end

        it 'processes only batch size number of records' do
          expect(result).to eq(processed_count: 1, skipped_count: 0)
          expect_delivery_jobs_count(1)
        end
      end
    end

    context 'when there are orphaned rotation records' do
      let!(:version_mismatch_rotation_info) do
        create(:secret_rotation_info,
          project: project1,
          secret_name: secret_1.name,
          rotation_interval_days: 30,
          next_reminder_at: 10.minutes.ago,
          last_reminder_at: nil,
          secret_metadata_version: 99
        )
      end

      let!(:orphaned_rotation_info) do
        create(:secret_rotation_info,
          project: project1,
          secret_name: 'DELETED_SECRET',
          rotation_interval_days: 30,
          next_reminder_at: 10.minutes.ago,
          last_reminder_at: nil
        )
      end

      before do
        # Make secret 1 and 2 eligible for reminder
        secret_1.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)
        secret_2.rotation_info.update_column(:next_reminder_at, 10.minutes.ago)

        # But make secret 2 have an inactive secrets manager which would make it orphaned
        secrets_manager2.initiate_deprovision!
      end

      it 'processes valid secrets and skips and cleans up orphaned records' do
        expect(result).to eq(processed_count: 1, skipped_count: 3)

        expect_delivery_jobs_count(1)
        expect_enqueud_email(owner1.id, project1.id, 'SECRET_1', mail: "secret_rotation_reminder_email")

        secret_1.rotation_info.reload
        expect(secret_1.rotation_info.last_reminder_at).to be_present
        expect(secret_1.rotation_info.next_reminder_at).to be_future

        expect(SecretsManagement::SecretRotationInfo.exists?(secret_2.rotation_info.id)).to be_falsey
        expect(SecretsManagement::SecretRotationInfo.exists?(version_mismatch_rotation_info.id)).to be_falsey
        expect(SecretsManagement::SecretRotationInfo.exists?(orphaned_rotation_info.id)).to be_falsey
      end
    end
  end
end
