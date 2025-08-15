# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateWorkflowService, feature_category: :duo_workflow do
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
      allow(Ability).to receive(:allowed?).with(user, :duo_workflow, container).and_return(true)
    end

    it 'creates a new workflow' do
      expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

      expect(execute[:workflow]).to be_a(Ai::DuoWorkflows::Workflow)
      expect(execute[:workflow].user).to eq(user)
      expect(execute[:workflow].project).to eq(project)
    end

    it 'sends session create event' do
      expect { execute }.to trigger_internal_events("create_agent_platform_session")
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

    context 'when namespace-level workflow' do
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

    context 'when container is nil' do
      let(:container) { nil }

      it 'returns error' do
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
        expect(execute[:message]).to include('Something bad')
      end
    end
  end
end
