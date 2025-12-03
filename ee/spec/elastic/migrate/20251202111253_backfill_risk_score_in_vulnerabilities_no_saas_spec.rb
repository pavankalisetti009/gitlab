# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251202111253_backfill_risk_score_in_vulnerabilities_no_saas.rb')

RSpec.describe BackfillRiskScoreInVulnerabilitiesNoSaas, feature_category: :vulnerability_management do
  let(:version) { 20251202111253 }
  let(:migration) { described_class.new(version) }

  describe 'skip_migration?' do
    context 'when BackfillVulnerabilityFindingRiskScores migration does not exist' do
      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillVulnerabilityFindingRiskScores', :vulnerability_occurrences, :id, [])
          .and_return(nil)
      end

      it 'returns true (skips the migration)' do
        expect(migration.skip_migration?).to be_truthy
      end
    end

    context 'when BackfillVulnerabilityFindingRiskScores migration exists but is nor completed' do
      let(:batched_migration) do
        instance_double(Gitlab::Database::BackgroundMigration::BatchedMigration, finished?: false, finalized?: false)
      end

      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillVulnerabilityFindingRiskScores', :vulnerability_occurrences, :id, [])
          .and_return(batched_migration)
      end

      it 'returns true (skips the migration)' do
        expect(migration.skip_migration?).to be_truthy
      end
    end

    context 'when BackfillVulnerabilityFindingRiskScores migration has finished' do
      let(:batched_migration) do
        instance_double(Gitlab::Database::BackgroundMigration::BatchedMigration, finished?: true, finalized?: false)
      end

      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillVulnerabilityFindingRiskScores', :vulnerability_occurrences, :id, [])
          .and_return(batched_migration)
      end

      it 'returns false (does not skip the migration)' do
        expect(migration.skip_migration?).to be_falsey
      end
    end

    context 'when BackfillVulnerabilityFindingRiskScores migration has finalized' do
      let(:batched_migration) do
        instance_double(Gitlab::Database::BackgroundMigration::BatchedMigration, finished?: false, finalized?: true)
      end

      before do
        allow(Gitlab::Database::BackgroundMigration::BatchedMigration)
          .to receive(:find_for_configuration)
          .with(:gitlab_sec, 'BackfillVulnerabilityFindingRiskScores', :vulnerability_occurrences, :id, [])
          .and_return(batched_migration)
      end

      it 'returns false (does not skip the migration)' do
        expect(migration.skip_migration?).to be_falsey
      end
    end
  end

  describe 'migration', :elastic do
    it_behaves_like 'migration reindexes all data' do
      let(:objects) { create_list(:vulnerability_read, 3) }
      let(:factory_to_create_objects) { :vulnerability_read }
      let(:expected_throttle_delay) { 30.seconds }
      let(:expected_batch_size) { 30_000 }
    end
  end
end
