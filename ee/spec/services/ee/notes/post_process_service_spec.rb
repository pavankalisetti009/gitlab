# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::PostProcessService, feature_category: :team_planning do
  describe '#execute' do
    context 'analytics' do
      subject { described_class.new(note) }

      let(:note) { create(:note) }
      let(:analytics_mock) { instance_double('Analytics::RefreshCommentsData') }

      it 'invokes Analytics::RefreshCommentsData' do
        allow(Analytics::RefreshCommentsData).to receive(:for_note).with(note).and_return(analytics_mock)

        expect(analytics_mock).to receive(:execute)

        subject.execute
      end
    end

    context 'for audit events' do
      subject(:notes_post_process_service) { described_class.new(note) }

      context 'when note author is a project bot' do
        let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }

        let(:note) { create(:note, author: project_bot) }

        it 'audits with correct name' do
          # Stub .audit here so that only relevant audit events are received below
          allow(::Gitlab::Audit::Auditor).to receive(:audit)

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(name: "comment_by_project_bot", stream_only: true)
          ).and_call_original

          notes_post_process_service.execute
        end

        it 'does not persist the audit event to database' do
          expect { notes_post_process_service.execute }.not_to change { AuditEvent.count }
        end
      end

      context 'when note author is not a project bot' do
        let(:note) { create(:note) }

        it 'does not invoke Gitlab::Audit::Auditor' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(hash_including(
            name: 'comment_by_project_bot'
          ))

          notes_post_process_service.execute
        end

        it 'does not create an audit event' do
          expect { notes_post_process_service.execute }.not_to change { AuditEvent.count }
        end
      end
    end

    context 'for processing Duo Code Review chat' do
      let_it_be(:project) { create(:project, :repository) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let_it_be(:note) { create(:diff_note_on_merge_request, noteable: merge_request, project: project) }

      subject(:execute) { described_class.new(note).execute }

      shared_examples_for 'not enqueueing MergeRequests::DuoCodeReviewChatWorker' do
        it 'does not enqueue MergeRequests::DuoCodeReviewChatWorker' do
          expect(::MergeRequests::DuoCodeReviewChatWorker).not_to receive(:perform_async)

          execute
        end
      end

      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(true)
        allow(note).to receive(:duo_bot_mentioned?).and_return(true)
      end

      it 'enqueues MergeRequests::DuoCodeReviewChatWorker' do
        expect(::MergeRequests::DuoCodeReviewChatWorker).to receive(:perform_async).with(note.id)

        execute
      end

      context 'when note is authored by GitLab Duo' do
        before do
          allow(note).to receive(:authored_by_duo_bot?).and_return(true)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end

      context 'when MergeRequest#ai_review_merge_request_allowed? returns false' do
        before do
          allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(false)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end

      context 'when Note#duo_bot_mentioned? returns false' do
        before do
          allow(note).to receive(:duo_bot_mentioned?).and_return(false)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end
    end

    context 'for processing AI flow triggers' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project) { create(:project, developers: [user]) }
      let_it_be(:mentioned_user) { create(:user) }
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be(:note) { create(:note, project: project, noteable: issue, author: user) }
      let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

      let_it_be(:flow_trigger) do
        create(:ai_flow_trigger, project: project, user: mentioned_user)
      end

      subject(:execute) { described_class.new(note).execute }

      before do
        allow(note).to receive_messages({
          mentioned_users: [mentioned_user],
          note: "Test note content"
        })
      end

      shared_examples_for 'not running AI flow trigger service' do
        it 'does not call Ai::FlowTriggers::RunService' do
          expect(::Ai::FlowTriggers::RunService).not_to receive(:new)
          execute
        end
      end

      context 'when author can trigger AI flow' do
        let_it_be(:subscription_assignment) do
          create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: subscription_purchase)
        end

        context 'when there is a matching flow trigger' do
          it 'calls Ai::FlowTriggers::RunService with correct parameters' do
            service_instance = instance_double('Ai::FlowTriggers::RunService')

            expect(::Ai::FlowTriggers::RunService).to receive(:new).with(
              project: project,
              current_user: user,
              resource: issue,
              flow_trigger: flow_trigger
            ).and_return(service_instance)

            expect(service_instance).to receive(:execute).with({
              input: "Test note content",
              event: :mention
            })

            execute
          end

          context 'when multiple users are mentioned but only one has a trigger' do
            let(:other_mentioned_user) { create(:user) }

            before do
              allow(note).to receive(:mentioned_users).and_return([mentioned_user, other_mentioned_user])
            end

            it 'still triggers the service for the matching user' do
              service_instance = instance_double('Ai::FlowTriggers::RunService')

              expect(::Ai::FlowTriggers::RunService).to receive(:new).and_return(service_instance)
              expect(service_instance).to receive(:execute)

              execute
            end
          end

          context 'when multiple flow triggers exist but only one matches' do
            let_it_be(:other_flow_trigger) do
              create(:ai_flow_trigger, project: project, user: create(:user))
            end

            it 'uses the first matching flow trigger' do
              service_instance = instance_double('Ai::FlowTriggers::RunService')

              expect(::Ai::FlowTriggers::RunService).to receive(:new).with(
                hash_including(flow_trigger: flow_trigger)
              ).and_return(service_instance)

              expect(service_instance).to receive(:execute)

              execute
            end
          end
        end

        context 'when there is no matching flow trigger' do
          before do
            allow(note).to receive(:mentioned_users).and_return([create(:user)])
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when no users are mentioned' do
          before do
            allow(note).to receive(:mentioned_users).and_return([])
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when flow trigger exists but for different trigger type' do
          before do
            stub_const("::Ai::FlowTrigger::EVENT_TYPES", {
              mention: 0,
              comment: 1,
              issue_created: 2
            })

            flow_trigger.update!(event_types: [1, 2])
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when project has no ai_flow_triggers association' do
          before do
            flow_trigger.destroy!
          end

          it_behaves_like 'not running AI flow trigger service'
        end
      end

      context 'when author cannot trigger AI flow' do
        it_behaves_like 'not running AI flow trigger service'
      end
    end
  end
end
