# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Migration, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    it { is_expected.to belong_to(:connection).class_name('Ai::ActiveContext::Connection') }
  end

  describe 'validations' do
    describe 'version' do
      it { is_expected.to validate_presence_of(:version) }

      context 'for uniqueness validations' do
        let!(:existing_migration) { create(:ai_active_context_migration) }

        it 'validates uniqueness of version scoped to connection_id' do
          new_migration = build(:ai_active_context_migration,
            connection: existing_migration.connection,
            version: existing_migration.version)

          expect(new_migration).not_to be_valid
          expect(new_migration.errors[:version]).to include('has already been taken')
        end

        it 'allows same version for different connections' do
          new_migration = build(:ai_active_context_migration,
            version: existing_migration.version)

          expect(new_migration).to be_valid
        end
      end

      context 'when validating format' do
        let(:migration) { build(:ai_active_context_migration) }

        where(:version, :valid) do
          '20250212093911'  | true   # Valid 14-digit timestamp
          '20250212093'     | false  # Too short
          '2025021209391a'  | false  # Contains non-digit
          '202502120939111' | false  # Too long
          nil               | false  # Nil value
          ''                | false  # Empty string
        end

        with_them do
          before do
            migration.version = version
          end

          it 'validates version format correctly' do
            expect(migration.valid?).to eq(valid)

            expect(migration.errors[:version]).to include('must be a 14-digit timestamp') unless valid
          end
        end
      end
    end

    describe 'status' do
      it { is_expected.to validate_presence_of(:status) }
    end

    describe 'retries_left' do
      let(:migration) { build(:ai_active_context_migration) }

      context 'when validating numericality' do
        where(:retries_left_value, :status_value, :valid) do
          -1                                 | 'pending'     | false  # Negative value
          0                                  | 'failed'      | true   # Minimum allowed value with failed status
          1                                  | 'pending'     | true   # Valid value
        end

        with_them do
          it 'validates retries_left value correctly' do
            migration.retries_left = retries_left_value
            migration.status = status_value
            expect(migration.valid?).to eq(valid)

            expect(migration.errors[:retries_left]).to be_present unless valid
          end
        end
      end

      it 'does not allow nil value' do
        migration.retries_left = nil
        expect(migration).to be_invalid
      end

      context 'when retries_left is 0' do
        before do
          migration.retries_left = 0
        end

        it 'is valid when status is failed' do
          migration.status = 'failed'
          expect(migration).to be_valid
        end

        it 'is invalid when status is not failed' do
          migration.status = 'pending'
          expect(migration).not_to be_valid
          expect(migration.errors[:retries_left]).to include('can only be 0 when status is failed')
        end
      end
    end
  end

  describe 'database constraints' do
    let(:migration) { create(:ai_active_context_migration) }

    it 'enforces version format through check constraint' do
      expect do
        # Using update_column bypasses validations but runs SQL
        migration.update_column(:version, 'invalid')
      end.to raise_error(ActiveRecord::StatementInvalid, /violates check constraint/)
    end

    it 'enforces retries constraint through check constraint' do
      expect do
        # Using update_columns to update multiple columns while bypassing validations
        migration.update_columns(
          retries_left: 0,
          status: described_class.statuses[:pending]
        )
      end.to raise_error(ActiveRecord::StatementInvalid, /violates check constraint/)
    end

    it 'enforces non-negative retries_left through check constraint' do
      expect do
        # Using update_column bypasses validations but runs SQL
        migration.update_column(:retries_left, -1)
      end.to raise_error(ActiveRecord::StatementInvalid, /violates check constraint/)
    end

    it 'enforces unique combination of connection_id and version' do
      existing = create(:ai_active_context_migration)
      new_migration = build(:ai_active_context_migration, connection: existing.connection, version: existing.version)

      expect do
        new_migration.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
