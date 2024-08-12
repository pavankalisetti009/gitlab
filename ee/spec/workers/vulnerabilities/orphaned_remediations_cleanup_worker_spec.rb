# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::OrphanedRemediationsCleanupWorker, feature_category: :vulnerability_management, type: :job do
  before do
    # with findings
    create(:vulnerabilities_remediation, findings: create_list(:vulnerabilities_finding, 1))
    # without_findings
    create(:vulnerabilities_remediation, findings: [])
  end

  shared_examples 'removes all orphaned remediations' do
    it 'deletes remediations that do not have any findings' do
      start_count = Vulnerabilities::Remediation.count
      end_count = start_count - Vulnerabilities::Remediation.where.missing(:findings).count

      expect { perform }.to change { Vulnerabilities::Remediation.count }.from(start_count).to(end_count)
    end
  end

  let_it_be(:stats_key) do
    [
      ApplicationWorker::LOGGING_EXTRA_KEY,
      'vulnerabilities_orphaned_remediations_cleanup_worker',
      'stats'
    ].join('.')
  end

  shared_examples 'builds stats from the response' do |expected_stats|
    it 'includes the number of batches and rows deleted in the metadata' do
      expect { perform }.to change {
        worker.logging_extras[stats_key]
      }.from(nil).to(expected_stats)
    end
  end

  describe '.perform' do
    subject(:perform) { worker.perform }

    let(:worker) { described_class.new }

    it_behaves_like 'removes all orphaned remediations'
    it_behaves_like 'builds stats from the response', { batches: 1, rows_deleted: 1 }

    context 'when orphaned remediations span multiple batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
        create_list(:vulnerabilities_remediation, 2, findings: [])
      end

      it_behaves_like 'removes all orphaned remediations'
      it_behaves_like 'builds stats from the response', { batches: 3, rows_deleted: 3 }

      context 'when a batch raise an exception' do
        let(:expected_metadata) { { batches: 2, rows_deleted: 2 } }

        before do
          last_orphan = Vulnerabilities::Remediation.where.missing(:findings).last

          # rubocop:disable RSpec/AnyInstanceOf -- the auto-correct generates syntactically invalid code
          allow_any_instance_of(ActiveRecord::Relation).to receive(:delete_all) do |batch|
            raise(ActiveRecord::QueryCanceled, "Error on last batch") if batch.first == last_orphan

            1 # fake a deletion
          end
          # rubocop:enable RSpec/AnyInstanceOf
        end

        it 'still logs the metadata' do
          expect { perform }.to raise_error(ActiveRecord::QueryCanceled)
          expect(worker.logging_extras[stats_key]).to eq expected_metadata
        end
      end
    end
  end
end
