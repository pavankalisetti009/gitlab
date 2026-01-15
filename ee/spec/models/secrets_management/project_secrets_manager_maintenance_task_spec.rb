# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagerMaintenanceTask, feature_category: :secrets_management do
  subject(:task) { build(:project_secrets_manager_maintenance_task) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:project_secrets_manager).class_name('SecretsManagement::ProjectSecretsManager') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:action) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:project_secrets_manager_id) }

    it { is_expected.to validate_numericality_of(:retry_count).only_integer.is_greater_than_or_equal_to(0) }

    it 'validates uniqueness of action scoped to project_secrets_manager_id' do
      project_secrets_manager = create(:project_secrets_manager)
      user = create(:user)

      create(:project_secrets_manager_maintenance_task,
        project_secrets_manager: project_secrets_manager,
        user: user,
        action: :provision
      )

      duplicate = build(:project_secrets_manager_maintenance_task,
        project_secrets_manager: project_secrets_manager,
        user: user,
        action: :provision
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:action]).to include('has already been taken')
    end

    it 'enforces uniqueness on (project_secrets_manager_id, action) at the database level' do
      existing = create(:project_secrets_manager_maintenance_task, action: :provision)

      duplicate = build(:project_secrets_manager_maintenance_task,
        user: existing.user,
        project_secrets_manager: existing.project_secrets_manager,
        action: :provision,
        retry_count: 0
      )

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:action).with_values(provision: 0, deprovision: 1) }
  end

  describe '.stale' do
    let_it_be(:stale_task) { create(:project_secrets_manager_maintenance_task, :stale, last_processed_at: 1.hour.ago) }
    let_it_be(:recent_task) do
      create(:project_secrets_manager_maintenance_task, :processing, last_processed_at: 10.minutes.ago)
    end

    it 'returns tasks older than the threshold' do
      threshold = 1.hour

      expect(described_class.stale(threshold)).to include(stale_task)
      expect(described_class.stale(threshold)).not_to include(recent_task)
    end

    it 'respects different threshold values' do
      threshold = 3.hours

      # Task stale for 2 hours won't be included with 3 hour threshold
      expect(described_class.stale(threshold)).not_to include(stale_task)
    end
  end

  describe '.retryable' do
    let_it_be(:retryable_task) { create(:project_secrets_manager_maintenance_task, retry_count: 1) }
    let_it_be(:max_retried_task) { create(:project_secrets_manager_maintenance_task, retry_count: 3) }

    it 'returns tasks below the max retry count' do
      max_retries = 3

      expect(described_class.retryable(max_retries)).to include(retryable_task)
      expect(described_class.retryable(max_retries)).not_to include(max_retried_task)
    end

    it 'respects different max retry values' do
      max_retries = 1

      expect(described_class.retryable(max_retries)).not_to include(retryable_task)
    end
  end

  describe 'scopes combination' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project_secrets_manager) { create(:project_secrets_manager) }

    let_it_be(:stale_and_retryable) do
      create(:project_secrets_manager_maintenance_task,
        last_processed_at: 2.hours.ago,
        retry_count: 1,
        action: :provision,
        user: user,
        project_secrets_manager: project_secrets_manager)
    end

    let_it_be(:stale_but_max_retries) do
      create(:project_secrets_manager_maintenance_task,
        last_processed_at: 2.hours.ago,
        retry_count: 3,
        action: :deprovision,
        user: user,
        project_secrets_manager: project_secrets_manager)
    end

    it 'chains stale and retryable scopes correctly' do
      results = described_class.stale(1.hour).retryable(3)

      expect(results).to include(stale_and_retryable)
      expect(results).not_to include(stale_but_max_retries)
    end
  end

  describe 'database constraints' do
    it 'cascades delete from project_secrets_manager to maintenance tasks' do
      task = create(:project_secrets_manager_maintenance_task, last_processed_at: Time.zone.now, action: :deprovision)

      expect do
        task.project_secrets_manager.destroy!
      end.to change { described_class.count }.by(-1)

      expect(described_class.exists?(task.id)).to be(false)
    end
  end
end
