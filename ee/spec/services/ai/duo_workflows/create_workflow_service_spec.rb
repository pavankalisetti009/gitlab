# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateWorkflowService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let(:container) { project }
    let(:params) { { environment: "ide" } }

    subject(:execute) do
      described_class
        .new(container: container, current_user: user, params: params)
        .execute
    end

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :duo_workflow, container).and_return(true)
    end

    it 'creates a new workflow' do
      expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

      expect(execute[:workflow]).to be_a(Ai::DuoWorkflows::Workflow)
      expect(execute[:workflow].user).to eq(user)
      expect(execute[:workflow].project).to eq(project)
    end

    it 'sends session create event' do
      expect { execute }.to trigger_internal_events("agent_platform_session_created")
                              .with(category: "Ai::DuoWorkflows::CreateWorkflowService",
                                user: user,
                                project: project,
                                additional_properties: {
                                  label: "software_development",
                                  value: be_a(Integer),
                                  property: "ide"
                                }
                              )
    end

    context 'when namespace-level workflow',
      skip: 'Not yet supported. See https://gitlab.com/gitlab-org/gitlab/-/issues/554952' do
      let(:container) { group }

      it 'creates a new workflow' do
        expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
        expect(execute[:workflow]).to be_a(Ai::DuoWorkflows::Workflow)
        expect(execute[:workflow].user).to eq(user)
        expect(execute[:workflow].namespace).to eq(group)
      end
    end

    context 'when user cannot access duo agentic chat' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :duo_workflow, container).and_return(false)
      end

      it 'returns error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:http_status]).to eq(:forbidden)
        expect(execute[:message]).to include('forbidden to access duo workflow')
      end
    end

    context 'when container is not supported' do
      let(:container) { create(:ci_empty_pipeline) }

      it 'returns error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:http_status]).to eq(:bad_request)
        expect(execute[:message]).to include('container must be a Project or Namespace')
      end
    end

    context 'when workflow definition is chat' do
      let(:params) { { workflow_definition: 'chat' } }

      before do
        allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, container).and_return(true)
      end

      it 'creates a new workflow' do
        expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
        expect(execute[:workflow]).to be_a(Ai::DuoWorkflows::Workflow)
        expect(execute[:workflow].user).to eq(user)
        expect(execute[:workflow].project).to eq(project)
      end

      context 'when user cannot access duo agentic chat' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, container).and_return(false)
        end

        it 'returns error' do
          expect(execute[:status]).to eq(:error)
          expect(execute[:http_status]).to eq(:forbidden)
          expect(execute[:message]).to include('forbidden to access agentic chat')
        end
      end
    end

    context 'when workflow definition is foundational agent and workflow for namespace' do
      let(:params) { { workflow_definition: 'duo_planner/experimental' } }
      let(:container) { group }

      before do
        allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, container).and_return(true)
      end

      it 'creates a new workflow' do
        expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
        expect(execute[:workflow]).to be_a(Ai::DuoWorkflows::Workflow)
        expect(execute[:workflow].user).to eq(user)
      end
    end

    context 'when container is nil' do
      let(:container) { nil }

      it 'returns error' do
        allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(nil)

        expect(execute[:status]).to eq(:error)
        expect(execute[:http_status]).to eq(:bad_request)
        expect(execute[:message]).to include('container must be a Project or Namespace')
      end
    end

    context 'when the workflow cannot be saved' do
      before do
        allow_next_instance_of(Ai::DuoWorkflows::Workflow) do |instance|
          allow(instance).to receive(:save).and_return(false)
          instance.errors.add(:base, "Something bad")
        end
      end

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to eq('Something bad')
      end
    end

    context 'when project_id or namespace_id are provided in params' do
      let(:params) { { environment: "ide", project_id: project.id, namespace_id: group.id } }

      it 'ignores both ids and creates workflow using container' do
        expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        workflow = execute[:workflow]
        expect(workflow.project).to eq(container)
        expect(workflow.namespace).to be_nil
      end
    end

    context 'when ai_catalog_item_version is provided' do
      let_it_be(:ai_catalog_item) { create(:ai_catalog_item) }
      let_it_be(:ai_catalog_item_version) { create(:ai_catalog_item_version, item: ai_catalog_item) }
      let(:params) { { environment: "ide", ai_catalog_item_version: ai_catalog_item_version } }

      context 'when user has access to the AI catalog item' do
        before do
          allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
            allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: true))
          end
        end

        it 'creates a new workflow' do
          expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
          expect(execute[:workflow]).to be_a(Ai::DuoWorkflows::Workflow)
          expect(execute[:workflow].ai_catalog_item_version).to eq(ai_catalog_item_version)
        end
      end

      context 'when user does not have access to the AI catalog item' do
        before do
          allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
            allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: false))
          end
        end

        it 'returns error' do
          expect(execute[:status]).to eq(:error)
          expect(execute[:http_status]).to eq(:not_found)
          expect(execute[:message]).to include('ItemVersion not found')
        end
      end

      context 'with namespace-level workflow' do
        let(:container) { group }

        before do
          allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
            allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: true))
          end
        end

        it 'passes group_id to ItemConsumersFinder' do
          expect(Ai::Catalog::ItemConsumersFinder).to receive(:new).with(
            user,
            params: hash_including(group_id: group.id, item_id: ai_catalog_item.id)
          )

          execute
        end
      end

      context 'with project-level workflow' do
        before do
          allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
            allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: true))
          end
        end

        it 'passes project_id to ItemConsumersFinder' do
          expect(Ai::Catalog::ItemConsumersFinder).to receive(:new).with(
            user,
            params: hash_including(project_id: project.id, item_id: ai_catalog_item.id)
          )

          execute
        end
      end
    end

    context 'on system note creation' do
      context 'when noteable is an issue' do
        context 'when issue_id is valid' do
          let_it_be(:issue) { create(:issue, project: project) }
          let(:params) { { environment: "web", issue_id: issue.iid } }

          it 'creates a workflow associated with the issue' do
            expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

            workflow = execute[:workflow]
            expect(workflow.issue).to eq(issue)
          end

          it 'creates a system note on the issue' do
            expect(SystemNoteService).to receive(:agent_session_started).with(
              issue,
              project,
              be_a(Integer),
              user
            )

            execute
          end
        end

        context 'when issue_id is invalid' do
          let(:params) { { environment: "web", issue_id: 999999 } }

          it 'creates a workflow without issue association' do
            expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

            workflow = execute[:workflow]
            expect(workflow.issue).to be_nil
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_started)

            execute
          end
        end
      end

      context 'when SystemNoteService raises an error' do
        let_it_be(:issue) { create(:issue, project: project) }
        let(:params) { { environment: "web", issue_id: issue.iid } }

        before do
          allow(SystemNoteService).to receive(:agent_session_started).and_raise(StandardError, 'Note creation failed')
        end

        it 'tracks the exception and workflow creation continues successfully' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(StandardError),
            hash_including(
              workflow_id: be_a(Integer),
              noteable_type: 'Issue',
              noteable_id: issue.id
            )
          )

          expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
          expect(execute[:status]).to eq(:success)
        end

        it 'does not fail the workflow creation' do
          result = execute

          expect(result[:status]).to eq(:success)
          expect(result[:workflow]).to be_persisted
          expect(result[:workflow].issue).to eq(issue)
        end
      end

      context 'when finder raises an error' do
        context 'when IssuesFinder raises an error for issue_id' do
          let(:params) { { environment: "web", issue_id: 1 } }
          let(:error) { StandardError.new('Database connection failed') }

          before do
            allow_next_instance_of(IssuesFinder) do |finder|
              allow(finder).to receive(:execute).and_raise(error)
            end
          end

          it 'tracks the exception with issue_iid' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              error,
              hash_including(
                issue_iid: 1,
                container_id: project.id
              )
            )

            execute
          end

          it 'creates workflow without issue association' do
            workflow = execute[:workflow]

            expect(workflow).to be_persisted
            expect(workflow.issue).to be_nil
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_started)

            execute
          end
        end
      end

      context 'when noteable does not have a project' do
        let_it_be(:issue) { create(:issue, project: project) }
        let(:params) { { environment: "web", issue_id: issue.iid } }

        before do
          allow_next_found_instance_of(Issue) do |instance|
            allow(instance).to receive(:project).and_return(nil)
          end
        end

        it 'does not create a system note' do
          expect(SystemNoteService).not_to receive(:agent_session_started)

          execute
        end

        it 'still creates the workflow successfully' do
          expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
          expect(execute[:status]).to eq(:success)
        end
      end

      context 'when noteable project is not present' do
        let_it_be(:issue) { create(:issue, project: project) }
        let(:params) { { environment: "web", issue_id: issue.iid } }
        let(:empty_project) { instance_double(Project, present?: false) }

        before do
          allow_next_found_instance_of(Issue) do |instance|
            allow(instance).to receive(:project).and_return(empty_project)
          end
        end

        it 'does not create a system note' do
          expect(SystemNoteService).not_to receive(:agent_session_started)

          execute
        end

        it 'still creates the workflow successfully' do
          expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
          expect(execute[:status]).to eq(:success)
        end
      end

      context 'when noteable does not respond to project method' do
        let_it_be(:issue) { create(:issue, project: project) }
        let(:params) { { environment: "web", issue_id: issue.iid } }

        before do
          allow_next_instance_of(IssuesFinder) do |finder|
            allow(finder).to receive(:execute).and_return(Issue.none)
          end
        end

        it 'does not create a system note' do
          expect(SystemNoteService).not_to receive(:agent_session_started)

          execute
        end

        it 'creates workflow without issue association' do
          workflow = execute[:workflow]

          expect(workflow).to be_persisted
          expect(workflow.issue_id).to be_nil
        end
      end

      context 'when container is not a Project' do
        let(:container) { group }
        let(:params) { { environment: "web", issue_id: 1, workflow_definition: 'chat' } }

        before do
          allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, container).and_return(true)
        end

        it 'does not attempt to find the issue' do
          expect(IssuesFinder).not_to receive(:new)

          execute
        end

        it 'creates workflow without issue association' do
          workflow = execute[:workflow]

          expect(workflow).to be_persisted
          expect(workflow.issue).to be_nil
          expect(workflow.namespace).to eq(group)
        end
      end
    end
  end
end
