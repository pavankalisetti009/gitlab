# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe UpdateRequirePatExpiryInApplicationSettings, feature_category: :system_access do
  let(:application_settings_table) { table(:application_settings) }
  let(:batched_background_migrations_table) { table(:batched_background_migrations) }

  describe '#up' do
    before do
      application_settings_table.create!(require_personal_access_token_expiry: true)
    end

    context 'when PAT expiry backfilling migration has run' do
      it 'leaves the PAT expiry enforcement in application settings enabled' do
        batched_background_migrations_table.create!(
          job_class_name: 'CleanupPersonalAccessTokensWithNilExpiresAt',
          table_name: 'personal_access_tokens',
          column_name: 'id',
          interval: 120,
          min_value: 1,
          max_value: 42,
          batch_size: 10,
          sub_batch_size: 5,
          gitlab_schema: 'gitlab_main')

        migrate!

        expect(ApplicationSetting.last.require_personal_access_token_expiry).to eq(true)
      end
    end

    context 'when PAT expiry backfilling migration has not been run' do
      it 'disables the PAT expirty enforcement in application settings' do
        migrate!

        expect(ApplicationSetting.last.require_personal_access_token_expiry).to eq(false)
      end
    end
  end
end
