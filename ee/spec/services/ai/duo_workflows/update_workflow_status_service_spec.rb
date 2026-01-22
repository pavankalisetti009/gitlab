# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::UpdateWorkflowStatusService, feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:result) { described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute }

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:another_user) { create(:user) }
    let(:workflow_initial_status_enum) { 1 }

    let(:duo_workflow) do
      create(:duo_workflows_workflow, project: project, user: user, status: workflow_initial_status_enum)
    end

    let(:chat_workflow) do
      create(:duo_workflows_workflow, :agentic_chat, project: project, user: user, status: workflow_initial_status_enum)
    end

    let(:workflow) { duo_workflow }

    context "when duo workflow is not available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
      end

      it "returns not found", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not update workflow")
        expect(result[:reason]).to eq(:unauthorized)
        expect(workflow.reload.human_status_name).to eq("running")
      end
    end

    context "when duo workflow is available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(user).to receive(:allowed_to_use?).and_return(true)
      end

      it "can finish a workflow", :aggregate_failures do
        time = 3.days.ago
        ts = time.change(nsec: (time.nsec / 1000) * 1000)
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow, created_at: ts, project: workflow.project)
        expect(GraphqlTriggers).to receive(:workflow_events_updated).with(checkpoint).and_return(1)

        expect do
          result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute
          expect(result[:status]).to eq(:success)
          expect(result[:message]).to eq("Workflow status updated")
        end.to trigger_internal_events("agent_platform_session_finished")
                           .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                             user: workflow.user,
                             project: workflow.project,
                             additional_properties: {
                               label: workflow.workflow_definition,
                               value: workflow.id,
                               property: "ide"
                             })

        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it 'creates an audit event when finishing a workflow' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'duo_session_finished',
            author: user,
            scope: project,
            target: workflow,
            message: 'Completed Duo session'
          )
        )

        described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute
      end

      context 'when audit event creation fails for finish event' do
        let(:audit_error) { StandardError.new('Audit service unavailable') }

        before do
          allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
        end

        it 'tracks the exception and workflow update continues successfully' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            audit_error,
            hash_including(workflow_id: workflow.id)
          )

          result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

          expect(result[:status]).to eq(:success)
          expect(workflow.reload.human_status_name).to eq("finished")
        end
      end

      it "can drop a workflow", :aggregate_failures do
        expect do
          result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

          expect(result[:status]).to eq(:success)
          expect(result[:message]).to eq("Workflow status updated")
        end.to trigger_internal_events("agent_platform_session_dropped")
                             .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                               user: workflow.user,
                               project: workflow.project,
                               additional_properties: {
                                 label: workflow.workflow_definition,
                                 value: workflow.id,
                                 property: "ide"
                               })

        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it 'creates an audit event when dropping a workflow' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'duo_session_failed',
            author: user,
            scope: project,
            target: workflow,
            message: 'Duo session failed'
          )
        )

        described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute
      end

      context 'when audit event creation fails for drop event' do
        let(:audit_error) { StandardError.new('Audit service unavailable') }

        before do
          allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
        end

        it 'tracks the exception and workflow update continues successfully' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            audit_error,
            hash_including(workflow_id: workflow.id)
          )

          result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

          expect(result[:status]).to eq(:success)
          expect(workflow.reload.human_status_name).to eq("failed")
        end
      end

      it "can pause a workflow", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "pause").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow status updated")
        expect(workflow.reload.human_status_name).to eq("paused")
      end

      context "when stopping workflow" do
        it "can stop a workflow without associated pipelines", :aggregate_failures do
          allow(workflow).to receive(:associated_pipelines).and_return([])

          expect do
            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:success)
            expect(result[:message]).to eq("Workflow status updated")
          end.to trigger_internal_events("agent_platform_session_stopped")
                                 .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                                   user: workflow.user,
                                   project: workflow.project,
                                   additional_properties: {
                                     label: workflow.workflow_definition,
                                     value: workflow.id,
                                     property: "ide"
                                   })

          expect(workflow.reload.human_status_name).to eq("stopped")
        end

        it 'creates an audit event when stopping a workflow' do
          allow(workflow).to receive(:associated_pipelines).and_return([])

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_session_stopped',
              author: user,
              scope: project,
              target: workflow,
              message: 'Duo session stopped'
            )
          )

          described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute
        end

        context 'when audit event creation fails for stop event' do
          let(:audit_error) { StandardError.new('Audit service unavailable') }

          before do
            allow(workflow).to receive(:associated_pipelines).and_return([])
            allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
          end

          it 'tracks the exception and workflow update continues successfully' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              audit_error,
              hash_including(workflow_id: workflow.id)
            )

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("stopped")
          end
        end

        context "with associated pipelines" do
          let(:pipeline1) { create(:ci_pipeline, project: project) }
          let(:pipeline2) { create(:ci_pipeline, project: project) }

          before do
            allow(workflow).to receive(:associated_pipelines).and_return([pipeline1, pipeline2])
          end

          it "cancels all cancelable pipelines successfully" do
            allow(pipeline1).to receive(:cancelable?).and_return(true)
            allow(pipeline2).to receive(:cancelable?).and_return(true)

            allow(::Ci::CancelPipelineService).to receive(:new).and_wrap_original do |method, **kwargs|
              service = method.call(**kwargs)
              allow(service).to receive(:execute).and_return(ServiceResponse.success)
              service
            end

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:success)
            expect(result[:message]).to eq("Workflow status updated")
            expect(workflow.reload.human_status_name).to eq("stopped")
          end

          it "skips non-cancelable pipelines" do
            allow(pipeline1).to receive(:cancelable?).and_return(false)
            allow(pipeline2).to receive(:cancelable?).and_return(true)

            service_double = instance_double(::Ci::CancelPipelineService)
            allow(service_double).to receive(:execute).and_return(ServiceResponse.success)
            allow(::Ci::CancelPipelineService).to receive(:new).and_return(service_double)

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("stopped")
            expect(::Ci::CancelPipelineService).to have_received(:new).once
          end

          it "returns error when single pipeline cancellation fails" do
            allow(pipeline1).to receive(:cancelable?).and_return(true)
            allow(pipeline2).to receive(:cancelable?).and_return(true)

            service_double = instance_double(::Ci::CancelPipelineService)
            allow(service_double).to receive(:execute).and_return(
              ServiceResponse.error(message: "Failed to cancel pipeline")
            )
            allow(::Ci::CancelPipelineService).to receive(:new).and_return(service_double)

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:error)
            expect(result[:message]).to include("Failed to cancel some pipelines")
            expect(result[:message]).to include("Pipeline #{pipeline1.id}")
            expect(workflow.reload.human_status_name).to eq("running")
          end

          it "includes all failed pipeline details in error message" do
            allow(pipeline1).to receive(:cancelable?).and_return(true)
            allow(pipeline2).to receive(:cancelable?).and_return(true)

            call_count = 0
            service_double = instance_double(::Ci::CancelPipelineService)
            allow(service_double).to receive(:execute) do
              call_count += 1
              ServiceResponse.error(message: "Error #{call_count}")
            end
            allow(::Ci::CancelPipelineService).to receive(:new).and_return(service_double)

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:error)
            expect(result[:message]).to include("Failed to cancel some pipelines")
            expect(result[:message]).to include("Pipeline #{pipeline1.id}: Error 1")
            expect(result[:message]).to include("Pipeline #{pipeline2.id}: Error 2")
          end

          it "handles mixed cancelable and non-cancelable pipelines" do
            allow(pipeline1).to receive(:cancelable?).and_return(true)
            allow(pipeline2).to receive(:cancelable?).and_return(false)

            service_double = instance_double(::Ci::CancelPipelineService)
            allow(service_double).to receive(:execute).and_return(ServiceResponse.success)
            allow(::Ci::CancelPipelineService).to receive(:new).and_return(service_double)

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("stopped")
            expect(::Ci::CancelPipelineService).to have_received(:new).once
          end

          it "stops workflow even if some pipelines fail to cancel" do
            allow(pipeline1).to receive(:cancelable?).and_return(true)
            allow(pipeline2).to receive(:cancelable?).and_return(true)

            call_count = 0
            service_double = instance_double(::Ci::CancelPipelineService)
            allow(service_double).to receive(:execute) do
              call_count += 1
              if call_count == 1
                ServiceResponse.error(message: "First pipeline failed")
              else
                ServiceResponse.success
              end
            end
            allow(::Ci::CancelPipelineService).to receive(:new).and_return(service_double)

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:error)
            expect(result[:message]).to include("Failed to cancel some pipelines")
            expect(workflow.reload.human_status_name).to eq("running")
          end
        end
      end

      it "can retry a running workflow", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "retry").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow already in status running")
        expect(workflow.reload.human_status_name).to eq("running")
      end

      context "when initial status is paused" do
        let(:workflow_initial_status_enum) { 2 } # status paused

        it "can resume a workflow", :aggregate_failures do
          expect do
            result = described_class.new(workflow: workflow, current_user: user, status_event: "resume").execute

            expect(result[:status]).to eq(:success)
            expect(result[:message]).to eq("Workflow status updated")
          end.to trigger_internal_events("agent_platform_session_resumed")
                  .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                    user: workflow.user,
                    project: workflow.project,
                    additional_properties: {
                      label: workflow.workflow_definition,
                      value: workflow.id,
                      property: "ide"
                    })
          expect(workflow.reload.human_status_name).to eq("running")
        end
      end

      context "when initial status is created" do
        let(:workflow_initial_status_enum) { 0 } # status created

        it "can start a workflow", :aggregate_failures do
          expect do
            result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

            expect(result[:status]).to eq(:success)
            expect(result[:message]).to eq("Workflow status updated")
          end.to trigger_internal_events("agent_platform_session_started")
                             .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                               user: workflow.user,
                               project: workflow.project,
                               additional_properties: {
                                 label: workflow.workflow_definition,
                                 value: workflow.id,
                                 property: "ide"
                               })

          expect(workflow.reload.human_status_name).to eq("running")
        end

        it 'creates an audit event when starting a workflow' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_session_started',
              author: user,
              scope: project,
              target: workflow,
              message: 'Started Duo session'
            )
          )

          described_class.new(workflow: workflow, current_user: user, status_event: "start").execute
        end

        context 'when audit event creation fails' do
          let(:audit_error) { StandardError.new('Audit service unavailable') }

          before do
            allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
          end

          it 'tracks the exception when starting a workflow and workflow update continues successfully' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              audit_error,
              hash_including(workflow_id: workflow.id)
            )

            result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("running")
          end
        end
      end

      it "does not update to not allowed status", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "another_event").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not update workflow status, unsupported event: another_event")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("running")
      end

      it "does not finish failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not finish workflow that has status failed")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it "does not stop failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not stop workflow that has status failed")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it "retries failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "retry").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow status updated")
        expect(workflow.reload.human_status_name).to eq("running")
      end

      it "does not drop finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not drop workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not pause finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "pause").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not pause workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not resume finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "resume").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not resume workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not retry finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "retry").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not retry workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not start failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not start workflow that has status failed")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it "does not allow user without permission to finish workflow", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: another_user, status_event: "finish").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not update workflow")
        expect(result[:reason]).to eq(:unauthorized)
        expect(workflow.reload.human_status_name).to eq("running")
      end

      context "when user lacks permission to update workflow during status event handling" do
        it "returns unauthorized error with specific message for stop event" do
          test_user = create(:user)
          call_count = 0

          allow(test_user).to receive(:can?) do
            call_count += 1
            call_count == 1
          end

          result = described_class.new(workflow: workflow, current_user: test_user, status_event: "stop").execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq("You do not have permission to cancel this session.")
          expect(result[:reason]).to eq(:unauthorized)
          expect(workflow.reload.human_status_name).to eq("running")
        end

        it "returns unauthorized error with specific message for finish event" do
          test_user = create(:user)
          call_count = 0

          allow(test_user).to receive(:can?) do
            call_count += 1
            call_count == 1
          end

          result = described_class.new(workflow: workflow, current_user: test_user, status_event: "finish").execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq("You do not have permission to cancel this session.")
          expect(result[:reason]).to eq(:unauthorized)
          expect(workflow.reload.human_status_name).to eq("running")
        end

        it "returns unauthorized error with specific message for drop event" do
          test_user = create(:user)
          call_count = 0

          allow(test_user).to receive(:can?) do
            call_count += 1
            call_count == 1
          end

          result = described_class.new(workflow: workflow, current_user: test_user, status_event: "drop").execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq("You do not have permission to cancel this session.")
          expect(result[:reason]).to eq(:unauthorized)
          expect(workflow.reload.human_status_name).to eq("running")
        end
      end

      it "allows updating to current status", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow already in status finished")
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      context "when duo_features_enabled settings is turned off" do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        after do
          project.project_setting.update!(duo_features_enabled: true)
        end

        it "returns not found", :aggregate_failures do
          result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq("Can not update workflow")
          expect(result[:reason]).to eq(:unauthorized)
          expect(workflow.reload.human_status_name).to eq("running")
        end
      end

      context 'on system note update' do
        let_it_be(:issue) { create(:issue, project: project) }

        context 'when workflow is associated with an issue' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              status: workflow_initial_status_enum
            )
          end

          context 'when finishing workflow' do
            it 'creates a completion system note on the issue' do
              expect(SystemNoteService).to receive(:agent_session_completed).with(
                issue,
                project,
                workflow.id
              )

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "finish"
              ).execute
            end
          end

          context 'when dropping workflow' do
            it 'creates a failure system note on the issue with "dropped" reason' do
              expect(SystemNoteService).to receive(:agent_session_failed).with(
                issue,
                project,
                workflow.id,
                'dropped'
              )

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "drop"
              ).execute
            end
          end

          context 'when stopping workflow' do
            it 'creates a failure system note on the issue with "stopped" reason' do
              expect(SystemNoteService).to receive(:agent_session_failed).with(
                issue,
                project,
                workflow.id,
                'stopped'
              )

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "stop"
              ).execute
            end
          end

          context 'when pausing workflow' do
            it 'does not create a system note' do
              expect(SystemNoteService).not_to receive(:agent_session_completed)
              expect(SystemNoteService).not_to receive(:agent_session_failed)

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "pause"
              ).execute
            end
          end

          context 'when SystemNoteService raises an error' do
            before do
              allow(SystemNoteService).to receive(:agent_session_completed)
                .and_raise(StandardError, 'Note creation failed')
            end

            it 'tracks the exception and workflow update completes successfully' do
              expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                instance_of(StandardError),
                hash_including(
                  workflow_id: workflow.id,
                  noteable_type: 'Issue',
                  noteable_id: issue.id
                )
              )

              result = described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "finish"
              ).execute

              expect(result[:status]).to eq(:success)
              expect(workflow.reload.human_status_name).to eq("finished")
            end
          end
        end

        context 'when workflow has no noteable association' do
          let(:workflow) do
            create(:duo_workflows_workflow, project: project, user: user, status: workflow_initial_status_enum)
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_completed)
            expect(SystemNoteService).not_to receive(:agent_session_failed)

            described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute
          end
        end

        context 'when noteable does not have a project' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              status: workflow_initial_status_enum
            )
          end

          before do
            allow(issue).to receive(:project).and_return(nil)
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_completed)
            expect(SystemNoteService).not_to receive(:agent_session_failed)

            described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute
          end

          it 'still updates the workflow status successfully' do
            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("finished")
          end
        end

        context 'when noteable project is not present' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              status: workflow_initial_status_enum
            )
          end

          let(:empty_project) { instance_double(Project, present?: false) }

          before do
            allow(issue).to receive(:project).and_return(empty_project)
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_completed)
            expect(SystemNoteService).not_to receive(:agent_session_failed)

            described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute
          end

          it 'still updates the workflow status successfully' do
            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("finished")
          end
        end

        context 'when system note creation fails for drop event' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              status: workflow_initial_status_enum
            )
          end

          before do
            allow(SystemNoteService).to receive(:agent_session_failed)
              .and_raise(StandardError, 'Failed note creation')
          end

          it 'tracks the exception but does not fail the workflow update' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(StandardError),
              hash_including(
                workflow_id: workflow.id,
                noteable_type: 'Issue',
                noteable_id: issue.id
              )
            )

            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "drop"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("failed")
          end
        end

        context 'when system note creation fails for stop event' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              status: workflow_initial_status_enum
            )
          end

          before do
            allow(SystemNoteService).to receive(:agent_session_failed)
              .and_raise(StandardError, 'Failed note creation')
          end

          it 'tracks the exception but does not fail the workflow update' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(StandardError),
              hash_including(
                workflow_id: workflow.id,
                noteable_type: 'Issue',
                noteable_id: issue.id
              )
            )

            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "stop"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("stopped")
          end
        end
      end
    end
  end
end
