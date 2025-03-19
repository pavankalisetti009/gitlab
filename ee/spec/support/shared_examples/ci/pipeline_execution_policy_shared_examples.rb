# frozen_string_literal: true

RSpec.shared_context 'with pipeline policy context' do
  let(:pipeline_policy_context) do
    Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(project: project, command: command)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(project: project)
  end

  let_it_be(:project) { create(:project, :repository) }
  let(:creating_policy_pipeline) { false }
  let(:current_policy) { FactoryBot.build(:pipeline_execution_policy_pipeline) }
  let(:execution_policy_pipelines) { [] }

  before do
    allow(pipeline_policy_context.pipeline_execution_context).to receive_messages(
      creating_policy_pipeline?: creating_policy_pipeline,
      policy_pipelines: execution_policy_pipelines,
      current_policy: creating_policy_pipeline ? current_policy : nil
    )
  end
end

RSpec.shared_examples 'creates PEP project schedules' do
  context "when policy isn't a pipeline execution schedule policy" do
    let_it_be(:security_policy) { create(:security_policy, :scan_execution_policy) }

    it "doesn't create project schedules" do
      expect { execute }.not_to change { Security::PipelineExecutionProjectSchedule.count }
    end
  end

  context 'when policy is a pipeline execution schedule policy' do
    let_it_be(:security_policy) do
      create(
        :security_policy,
        :pipeline_execution_schedule_policy,
        content: {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedules: [
            { type: 'daily',
              start_time: "03:00",
              time_window: {
                distribution: 'random',
                value: 43200
              } },
            { type: 'weekly',
              days: %w[Monday Sunday],
              start_time: "23:15",
              time_window: {
                distribution: 'random',
                value: 64800
              },
              timezone: "Europe/Berlin" }
          ]
        }
      )
    end

    it 'creates project schedules' do
      expect { execute }.to change { Security::PipelineExecutionProjectSchedule.count }.by(2)
    end

    describe 'persisted project schedules', time_travel_to: '2025-01-01 00:00:00' do # Wed, Jan 25th
      let(:expected_attributes) do
        [
          {
            cron: "0 3 * * *",
            cron_timezone: "UTC",
            time_window_seconds: 12.hours,
            next_run_at: Time.zone.parse("2025-01-01 03:00:00"),
            project_id: project.id,
            security_policy_id: security_policy.id
          },
          {
            cron: "15 23 * * 1,0",
            cron_timezone: "Europe/Berlin", # 1 hour ahead of UTC
            time_window_seconds: 18.hours,
            next_run_at: Time.zone.parse("2025-01-05 22:15:00"), # Sun, Jan 05th
            project_id: project.id,
            security_policy_id: security_policy.id
          }
        ]
      end

      specify :aggregate_failures do
        execute

        schedules = security_policy.security_pipeline_execution_project_schedules.order(id: :asc)

        schedules.each_with_index do |schedule, idx|
          expect(schedule).to have_attributes(expected_attributes[idx])
        end
      end
    end

    context 'with invalid schedules' do
      let(:valid_schedule) do
        { type: 'daily',
          start_time: "00:00",
          time_window: {
            distribution: 'random',
            value: -1
          } }
      end

      let(:invalid_schedule) { valid_schedule.clone.tap { |schedule| schedule[:time_window][:value] = -1 } }
      let(:error_message) { a_string_including('Time window seconds must be greater than or equal to 600') }

      before do
        security_policy.content = security_policy.content.merge(schedules: [valid_schedule, invalid_schedule])
        security_policy.save!(validate: false)
      end

      it 'reraises' do
        expect { execute }.to raise_error(ActiveRecord::RecordInvalid, error_message)
                                .and not_change { Security::PipelineExecutionProjectSchedule.count }.from(0)
      end
    end
  end
end
