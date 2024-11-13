# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'gitlab:work_items:epics', :silence_stdout, feature_category: :team_planning do
  before do
    Rake.application.rake_require 'tasks/gitlab/work_items/epics'
  end

  describe '#enable' do
    subject(:task) { run_rake_task('gitlab:work_items:epics:enable') }

    let(:checking_attributes) do
      %w[closed_at closed_by_id confidential description iid state_id title epic_issue related_links parent_id]
    end

    let(:database_estimate) { instance_double(Gitlab::Database::PgClass, cardinality_estimate: 100) }
    let(:progress_bar) { instance_double(ProgressBar::Base) }

    before do
      allow(Gitlab::Database::PgClass).to receive(:for_table).with('epics')
        .and_return(database_estimate)

      allow(ProgressBar).to receive(:create)
        .with(title: 'Verifying epics', total: 100, format: '%t: |%B| %c/%C')
        .and_return(progress_bar)

      allow(progress_bar).to receive(:finish)
    end

    context 'when bulk verification has no mismatches' do
      before do
        allow_next_instance_of(::Gitlab::EpicWorkItemSync::BulkVerification,
          a_hash_including(filter_attributes: match_array(checking_attributes))) do |instance|
          allow(instance).to receive(:verify)
            .and_yield({ valid: 20, mismatched: 0 })
            .and_yield({ valid: 35, mismatched: 0 })
            .and_return({ valid: 35, mismatched: 0 })
        end
      end

      it 'enables the feature flag and updates the progress bar' do
        expect(Feature).to receive(:enable).with(:work_item_epics)

        expect(progress_bar).to receive(:progress=).with(20)
        expect(progress_bar).to receive(:progress=).with(35)
        expect(progress_bar).to receive(:finish)

        expect { task }.to output(
          a_string_including("Verified 35 epics")
          .and(a_string_including("Successfully enabled work item epics"))
        ).to_stdout
      end
    end

    context 'when bulk verification has mismatches' do
      before do
        allow_next_instance_of(::Gitlab::EpicWorkItemSync::BulkVerification) do |instance|
          allow(instance).to receive(:verify)
          .and_yield({ valid: 4, mismatched: 1 })
          .and_yield({ valid: 5, mismatched: 0 })
          .and_return({ valid: 10, mismatched: 2 })
        end
      end

      it 'does not enable the feature flag' do
        expect(Feature).not_to receive(:enable).with(:work_item_epics)

        expect(progress_bar).to receive(:progress=).with(5)
        expect(progress_bar).to receive(:progress=).with(5)
        expect(progress_bar).to receive(:finish)

        expect { task }.to output(
          a_string_matching("2 out of 12 epics have attributes that are out of sync")
            .and(a_string_including("We are not able to enable work item epics right now"))
        ).to_stdout
      end
    end
  end

  describe '#disable' do
    subject(:task) { run_rake_task('gitlab:work_items:epics:disable') }

    it 'disables the feature flag' do
      expect(Feature).to receive(:disable).with(:work_item_epics)

      expect { task }.to output(a_string_including("Successfully disabled work item epics.")).to_stdout
    end
  end
end
