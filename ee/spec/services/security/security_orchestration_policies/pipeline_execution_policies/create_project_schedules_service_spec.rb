# frozen_string_literal: true

require 'spec_helper'

RSpec.describe(
  Security::SecurityOrchestrationPolicies::PipelineExecutionPolicies::CreateProjectSchedulesService,
  '#execute',
  time_travel_to: '2025-01-01 00:00:00', # Wed, Jan 25th
  feature_category: :security_policy_management) do
  let_it_be(:project) { create(:project) }
  let(:policy) do
    create(
      :security_policy,
      :pipeline_execution_schedule_policy,
      content: {
        content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
        schedules: schedules
      })
  end

  let(:schedules) do
    [{ type: 'daily',
       start_time: "23:30",
       time_window: {
         value: 2.hours.to_i,
         distribution: 'random'
       },
       timezone: "Atlantic/Cape_Verde" }, # 1 hour behind UTC
      { type: 'weekly',
        days: %w[Monday Tuesday],
        start_time: "12:00",
        time_window: {
          value: 4.hours.to_i,
          distribution: 'random'
        },
        timezone: "Europe/Berlin" }, # 1 hour ahead of UTC
      { type: 'monthly',
        days_of_month: [29, 31],
        start_time: "23:00",
        time_window: {
          value: 8.hours.to_i,
          distribution: 'random'
        } }]
  end

  let(:expected_attributes) do
    [
      {
        cron: "30 23 * * *",
        cron_timezone: "Atlantic/Cape_Verde",
        time_window_seconds: 7200,
        next_run_at: Time.zone.parse("2025-01-01 00:30:00"), # Thu, Jan 2nd
        project_id: project.id,
        security_policy_id: policy.id
      },
      {
        cron: "0 12 * * 1,2",
        cron_timezone: "Europe/Berlin", # 1 hour ahead of UTC
        time_window_seconds: 14400,
        next_run_at: Time.zone.parse("2025-01-06 11:00:00"), # Mon, Jan 6th
        project_id: project.id,
        security_policy_id: policy.id
      },
      {
        cron: "0 23 29,31 * *",
        cron_timezone: "UTC",
        time_window_seconds: 28800,
        next_run_at: Time.zone.parse("2025-01-29 23:00:00"), # Wed, Jan 29th
        project_id: project.id,
        security_policy_id: policy.id
      }
    ]
  end

  subject(:execute) { described_class.new(project: project, policy: policy).execute }

  specify do
    expect { execute }.to change { policy.security_pipeline_execution_project_schedules.count }.from(0).to(3)
  end

  specify :aggregate_failures do
    execute

    schedules = policy.security_pipeline_execution_project_schedules.order(id: :asc)

    schedules.each_with_index do |schedule, idx|
      expect(schedule).to have_attributes(expected_attributes[idx])
    end
  end

  it 'succeeds' do
    expect(execute[:status]).to be(:success)
  end

  context 'with invalid attributes' do
    let(:intervals) { Gitlab::Security::Orchestration::PipelineExecutionPolicies::Intervals }

    let(:invalid_interval) do
      intervals::Interval.new(cron: "* * * * *", time_window: 0, time_zone: "UTC")
    end

    let(:exception_message) do
      a_string_including('Time window seconds must be greater than or equal to 600')
    end

    let(:expected_log) do
      {
        "class" => described_class.name,
        "event" => described_class::EVENT_KEY,
        "exception_class" => ActiveRecord::RecordInvalid.name,
        "exception_message" => exception_message,
        "project_id" => project.id,
        "policy_id" => policy.id
      }
    end

    before do
      allow(intervals).to receive(:from_schedules).and_return([invalid_interval])
    end

    it 'logs and reraises the error', :aggregate_failures do
      expect(Gitlab::AppJsonLogger).to receive(:error).with(expected_log)

      expect { execute }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'with feature disabled' do
    before do
      stub_feature_flags(scheduled_pipeline_execution_policies: false)
    end

    specify do
      expect { execute }.not_to change { policy.security_pipeline_execution_project_schedules.count }
    end
  end

  context 'with already existing schedules' do
    let!(:existing_schedules) do
      create_list(:security_pipeline_execution_project_schedule, 3, project: project, security_policy: policy)
    end

    it 'does not create more schedules than before' do
      expect { execute }.not_to change {
        policy.security_pipeline_execution_project_schedules.for_project(project).count
      }

      expect(Security::PipelineExecutionProjectSchedule.where(id: existing_schedules.pluck(:id)).count).to eq(0)
    end
  end
end
