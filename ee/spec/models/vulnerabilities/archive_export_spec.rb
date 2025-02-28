# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ArchiveExport, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:author).class_name('User').required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date_range) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:format) }
    it { is_expected.not_to validate_presence_of(:file) }

    context 'when the status is `finished`' do
      subject { build(:vulnerability_archive_export, status: :finished) }

      it { is_expected.to validate_presence_of(:file) }
    end
  end

  describe 'state machine' do
    describe '#start' do
      let(:export) { create(:vulnerability_archive_export) }

      subject(:start) { export.start! }

      it 'changes the status of the export' do
        expect { start }.to change { export.reload.status }
      end

      it 'sets the `started_at` attribute', :freeze_time do
        expect { start }.to change { export.reload.started_at }.from(nil).to(Time.current)
      end
    end

    describe '#finish' do
      let(:export) { create(:vulnerability_archive_export, :with_csv_file, :running) }

      subject(:finish) { export.finish! }

      it 'changes the status of the export' do
        expect { finish }.to change { export.reload.status }.to('finished')
      end

      it 'sets the `finished_at` attribute', :freeze_time do
        expect { finish }.to change { export.reload.finished_at }.from(nil).to(Time.current)
      end
    end

    describe '#failed' do
      let(:export) { create(:vulnerability_archive_export, :running) }

      subject(:failed) { export.failed! }

      it 'changes the status of the export' do
        expect { failed }.to change { export.reload.status }.to('failed')
      end
    end

    describe '#reset_state' do
      let(:export) { create(:vulnerability_archive_export, :running) }

      subject(:reset_state) { export.reset_state! }

      it 'changes the status of the export' do
        expect { reset_state }.to change { export.reload.status }.to('created')
      end

      it 'resets the `started_at` attribute' do
        expect { reset_state }.to change { export.reload.started_at }.to(nil)
      end
    end
  end

  describe 'partition helpers' do
    let(:partitioning_strategy) { described_class.partitioning_strategy }
    let(:active_partition) { partitioning_strategy.active_partition }

    describe '.partitioning_strategy#detach_partition_if' do
      subject { partitioning_strategy.detach_partition_if.call(active_partition) }

      before do
        create(:vulnerability_archive_export, status: status_of_existing_record)
      end

      context 'when there is a non-purged record' do
        let(:status_of_existing_record) { :created }

        it { is_expected.to be_falsey }
      end

      context 'when there is no non-purged record' do
        let(:status_of_existing_record) { :purged }

        it { is_expected.to be_truthy }
      end
    end

    describe '.partitioning_strategy#next_partition_if' do
      subject { partitioning_strategy.next_partition_if.call(active_partition) }

      context 'when there is no record in the partition' do
        it { is_expected.to be_falsey }
      end

      context 'when there is at least one record in the partition', :freeze_time do
        before do
          create(:vulnerability_archive_export, created_at: record_created_at)
        end

        context 'when the first record in the partition is not older than 1 month' do
          let(:record_created_at) { 1.week.ago }

          it { is_expected.to be_falsey }
        end

        context 'when the first record in the partition is older than 1 month' do
          let(:record_created_at) { 2.months.ago }

          it { is_expected.to be_truthy }
        end
      end
    end
  end
end
