# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretRotationInfo, feature_category: :secrets_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    subject { build(:secret_rotation_info) }

    it { is_expected.to validate_presence_of(:secret_name) }
    it { is_expected.to validate_presence_of(:rotation_interval_days) }
    it { is_expected.to validate_presence_of(:secret_metadata_version) }
    it { is_expected.to validate_numericality_of(:rotation_interval_days).is_greater_than_or_equal_to(7) }
  end

  describe '#upsert', :freeze_time do
    let_it_be(:project) { create(:project) }

    let(:secret_name) { 'TEST_SECRET' }
    let(:rotation_interval_days) { 30 }
    let(:secret_metadata_version) { 1 }

    let(:rotation_info) do
      build(:secret_rotation_info,
        project: project,
        secret_name: secret_name,
        rotation_interval_days: rotation_interval_days,
        secret_metadata_version: secret_metadata_version
      )
    end

    subject(:result) { rotation_info.upsert }

    context 'when the record is valid' do
      context 'and no existing record exists' do
        it 'creates a new record' do
          expect { result }.to change { described_class.count }.by(1)
          expect(result).to be_truthy

          saved_record = described_class.find_by(
            project: project,
            secret_name: secret_name,
            secret_metadata_version: secret_metadata_version
          )

          expect(rotation_info.id).to eq(saved_record.id)
          expect(saved_record).to be_present
          expect(saved_record.rotation_interval_days).to eq(rotation_interval_days)
        end
      end

      context 'and an existing record exists with same unique keys' do
        let!(:existing_record) do
          create(:secret_rotation_info,
            project: project,
            secret_name: secret_name,
            secret_metadata_version: secret_metadata_version,
            rotation_interval_days: 60
          )
        end

        it 'updates the existing record' do
          expect { result }.not_to change { described_class.count }
          expect(result).to be_truthy

          existing_record.reload
          expect(rotation_info.id).to eq(existing_record.id)
          expect(existing_record.rotation_interval_days).to eq(rotation_interval_days)
        end
      end
    end

    context 'when the record is invalid' do
      context 'with invalid rotation_interval_days' do
        let(:rotation_interval_days) { 3 } # Less than minimum

        it 'returns false and sets errors' do
          expect { result }.not_to change { described_class.count }
          expect(result).to be_falsey
          expect(rotation_info.errors[:rotation_interval_days]).to include('must be greater than or equal to 7')
        end
      end
    end
  end
end
