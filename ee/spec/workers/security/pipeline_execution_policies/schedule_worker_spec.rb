# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::ScheduleWorker, feature_category: :security_policy_management do
  include ExclusiveLeaseHelpers

  describe '#perform' do
    let_it_be(:time_window) { 3.hours.to_i }
    let_it_be(:delay) { 42.minutes.to_i }
    let_it_be_with_refind(:schedule) do
      create(:security_pipeline_execution_project_schedule, time_window_seconds: time_window)
    end

    let(:worker) { described_class.new }

    subject(:perform) { worker.perform }

    before do
      allow(Random).to receive(:rand).and_return(delay)

      schedule.update!(next_run_at: 1.hour.ago)
    end

    it_behaves_like 'an idempotent worker' do
      it 'enqueues the run worker' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).to receive(:perform_in).with(delay, schedule.id)

        perform
      end

      it 'updates next_run_at' do
        expect { perform }.to change { schedule.reload.next_run_at }
      end

      context 'with feature disabled' do
        before do
          stub_feature_flags(scheduled_pipeline_execution_policies: false)
        end

        it 'does not enqueue the run worker' do
          expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to receive(:perform_async)

          perform
        end
      end
    end

    it 'avoids N+1 queries' do
      schedule.update!(next_run_at: 1.hour.ago)

      control_count = ActiveRecord::QueryRecorder.new { described_class.new.perform }.count

      schedule.update!(next_run_at: 1.hour.ago)
      schedule_2 = create(:security_pipeline_execution_project_schedule, time_window_seconds: time_window)
      schedule_2.update!(next_run_at: 1.hour.ago)

      # +4 queries to update next_run_at for one additional schedule
      expect { described_class.new.perform }.not_to exceed_query_limit(control_count + 4)
    end

    context 'when another worker is still running' do
      let(:lease_key) { described_class::LEASE_KEY }
      let(:timeout) { described_class::LEASE_TIMEOUT }
      let(:lease) { Gitlab::ExclusiveLease.new(lease_key, timeout: timeout).try_obtain }

      it 'does not enqueue the run worker' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to receive(:perform_in)
        expect(lease).not_to be_nil

        perform

        Gitlab::ExclusiveLease.cancel(lease_key, lease)
      end
    end

    context 'if cron is valid' do
      before do
        schedule.update!(cron: cron)
      end

      shared_examples 'schedules' do
        specify do
          expect { perform }.to change { schedule.reload.next_run_at }
        end

        it 'enqueues the run worker' do
          expect(Security::PipelineExecutionPolicies::RunScheduleWorker)
            .to receive(:perform_in).with(delay, schedule.id)

          perform
        end

        specify do
          expect(Gitlab::AppJsonLogger).not_to receive(:info)
        end
      end

      context 'when daily' do
        let(:cron) { '0 9 * * *' }

        it_behaves_like 'schedules'
      end

      context 'when weekly' do
        let(:cron) { '30 10 * * 1,3,5' }

        it_behaves_like 'schedules'
      end

      context 'when monthly' do
        let(:cron) { '0 3 1,15,30 * *' }

        it_behaves_like 'schedules'
      end
    end

    context 'if cron is invalid' do
      let_it_be(:valid_schedule) do
        create(:security_pipeline_execution_project_schedule, time_window_seconds: time_window)
      end

      before do
        schedule.cron = 'foobar'
        schedule.save!(validate: false)

        valid_schedule.update!(next_run_at: schedule.next_run_at)
      end

      it 'does not update next_run_at' do
        expect { perform }.not_to change { schedule.reload.next_run_at }
      end

      it 'does not enqueue the run worker for invalid schedules' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).not_to(
          receive(:perform_in).with(delay, schedule.id)
        )

        perform
      end

      it 'enqueues the run worker for valid schedules' do
        expect(Security::PipelineExecutionPolicies::RunScheduleWorker).to(
          receive(:perform_in).with(delay, valid_schedule.id)
        )

        perform
      end

      it 'logs the error' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          event: 'scheduled_scan_execution_policy_validation',
          message: 'Invalid cadence',
          project_id: schedule.project_id,
          cadence: schedule.cron
        )

        perform
      end
    end

    context 'when schedule time_window_seconds is greater than the time to the next run' do
      let(:cron) { '0 0 * * *' }

      before do
        schedule.update!(next_run_at: 1.day.ago, time_window_seconds: 2.days.to_i, cron: cron)
      end

      it 'uses the time to next run as time window' do
        travel_to(Time.zone.now.beginning_of_day + 1.hour) do
          expect(Random).to receive(:rand).with(23.hours.to_i)

          perform
        end
      end
    end
  end
end
