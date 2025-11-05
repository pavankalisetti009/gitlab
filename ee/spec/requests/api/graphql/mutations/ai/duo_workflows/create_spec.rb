# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AiDuoWorkflowCreate', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:licensed_developer) { create(:user) }
  let_it_be(:unlicensed_developer) { create(:user) }
  let_it_be(:group) { create(:group, developers: [licensed_developer, unlicensed_developer]) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project) }

  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, namespace: group)
  end

  let_it_be(:add_on_assignment) do
    create(:gitlab_subscription_user_add_on_assignment, user: licensed_developer, add_on_purchase: add_on_purchase)
  end

  let_it_be(:agent) do
    create(:ai_catalog_agent, project: other_project, public: true)
  end

  let_it_be(:agent_version) do
    create(:ai_catalog_agent_version, item: agent)
  end

  let_it_be(:agent_consumer) do
    create(:ai_catalog_item_consumer, item: agent, project: project)
  end

  let(:current_user) { licensed_developer }
  let(:container) { project }
  let(:workflow_type) { "default" }
  let(:input) do
    {
      goal: "Automate PR reviews",
      agent_privileges: [1, 2, 3],
      pre_approved_agent_privileges: [1],
      workflow_definition: workflow_type,
      allow_agent_to_request_user: true,
      environment: 'WEB',
      ai_catalog_item_version_id: agent_version.to_global_id,
      **container_input
    }
  end

  let(:container_input) { { project_id: project.to_global_id } }

  let(:mutation) do
    graphql_mutation(:ai_duo_workflow_create, input,
      <<-QL
        errors
        workflow {
          id
          projectId
          namespaceId
        }
      QL
    )
  end

  let(:mutation_response) { graphql_mutation_response(:ai_duo_workflow_create) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(ai_workflows: true, agentic_chat: true, ai_chat: true)
    project.root_ancestor.update!(experiment_features_enabled: true)
  end

  context 'when container is a project', :saas do
    where(:workflow_type) do
      %w[default chat]
    end

    with_them do
      it 'creates a new workflow' do
        expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).with(
          container: container,
          current_user: current_user,
          params: {
            goal: "Automate PR reviews",
            agent_privileges: [1, 2, 3],
            pre_approved_agent_privileges: [1],
            workflow_definition: workflow_type,
            allow_agent_to_request_user: true,
            environment: 'web',
            ai_catalog_item_version_id: agent_version.id
          }
        ).and_call_original

        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)

        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(mutation_response['workflow']['id']).to eq("gid://gitlab/Ai::DuoWorkflows::Workflow/#{workflow.id}")
        expect(mutation_response['workflow']['projectId']).to eq("gid://gitlab/Project/#{project.id}")
        expect(mutation_response['workflow']['namespaceId']).to be_nil
        expect(mutation_response['errors']).to be_empty
      end
    end
  end

  context 'when container is a namespace' do
    let(:container) { group }
    let(:container_input) { { namespace_id: group.to_global_id } }

    it 'creates a new workflow' do
      expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).with(
        container: container,
        current_user: current_user,
        params: {
          goal: "Automate PR reviews",
          agent_privileges: [1, 2, 3],
          pre_approved_agent_privileges: [1],
          workflow_definition: workflow_type,
          allow_agent_to_request_user: true,
          environment: 'web',
          ai_catalog_item_version_id: agent_version.id
        }
      ).and_call_original

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)

      if workflow_type == 'chat'
        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(mutation_response['workflow']['id']).to eq("gid://gitlab/Ai::DuoWorkflows::Workflow/#{workflow.id}")
        expect(mutation_response['workflow']['projectId']).to be_nil
        expect(mutation_response['workflow']['namespaceId']).to eq("gid://gitlab/Types::Namespace/#{group.id}")
        expect(mutation_response['errors']).to be_empty
      else
        # NOTE: Non-chat types do not support namespace-level workflow yet.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/554952.
        expect(graphql_errors.pluck('message')).to eq(['forbidden to access duo workflow'])
      end
    end
  end

  context 'with a public project', :saas do
    let_it_be(:container) do
      public_group = create(:group, :public)
      public_group.update!(experiment_features_enabled: true)
      create(:project, :public, group: public_group)
    end

    let(:workflow_type) { 'chat' }
    let(:container_input) { { project_id: container.to_global_id } }

    context 'when the user is licensed to use agentic chat' do
      it 'creates and returns a workflow' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(mutation_response['workflow']).to match a_graphql_entity_for(workflow)
      end

      context 'when user cannot use agent version' do
        let(:agent) { create(:ai_catalog_agent, project: other_project) }
        let(:agent_version) { create(:ai_catalog_agent_version, item: agent) }

        include_examples 'a mutation that returns top-level errors',
          errors: ['User is not authorized to use agent catalog item.']
      end

      context 'when an agent version is not provided' do
        let(:input) { super().merge(ai_catalog_item_version_id: nil) }

        it 'creates and returns a workflow' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty

          workflow = ::Ai::DuoWorkflows::Workflow.last
          expect(mutation_response['workflow']).to match a_graphql_entity_for(workflow)
        end
      end

      context 'when neither project_id nor namespace_id are specified' do
        let(:container_input) { {} }

        it 'uses the default duo namespace from user preferences' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          workflow = ::Ai::DuoWorkflows::Workflow.last
          expect(mutation_response['workflow']['id']).to eq("gid://gitlab/Ai::DuoWorkflows::Workflow/#{workflow.id}")
          expect(mutation_response['errors']).to be_empty
        end
      end
    end

    context 'when the user is not licensed to use the feature' do
      let(:current_user) { unlicensed_developer }

      before do
        post_graphql_mutation(mutation, current_user: current_user)
      end

      include_examples 'a mutation that returns top-level errors',
        errors: ['forbidden to access agentic chat']
    end
  end

  context 'when the service returns an error', :saas do
    it 'returns the error message' do
      service_result = ::ServiceResponse.error(
        message: 'Failed to create workflow',
        http_status: :error # rubocop: disable Gitlab/ServiceResponse -- requires refactoring in CreateWorkflowService
      )

      service = instance_double(::Ai::DuoWorkflows::CreateWorkflowService, execute: service_result)
      allow(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).and_return(service)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['workflow']).to be_nil
      expect(mutation_response['errors']).to eq(['Failed to create workflow'])
    end
  end

  context 'when the user is not authorized to use the feature', :saas do
    let(:current_user) { unlicensed_developer }

    where(:workflow_type) do
      %w[default unknown]
    end

    with_them do
      before do
        post_graphql_mutation(mutation, current_user: current_user)
      end

      include_examples 'a mutation that returns top-level errors',
        errors: ['forbidden to access duo workflow']
    end
  end

  context 'when a user is not authorized to use the agentic chat' do
    let(:current_user) { unlicensed_developer }
    let(:workflow_type) { 'chat' }

    before do
      post_graphql_mutation(mutation, current_user: current_user)
    end

    include_examples 'a mutation that returns top-level errors',
      errors: ['forbidden to access agentic chat']
  end

  context 'when both project_id and namespace_id are specified', :saas do
    let(:container_input) { { project_id: project.to_global_id, namespace_id: group.to_global_id } }

    it 'uses project_id and ignores namespace_id' do
      expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).with(
        container: project,
        current_user: current_user,
        params: {
          goal: "Automate PR reviews",
          agent_privileges: [1, 2, 3],
          pre_approved_agent_privileges: [1],
          workflow_definition: workflow_type,
          allow_agent_to_request_user: true,
          environment: 'web',
          ai_catalog_item_version_id: agent_version.id
        }
      ).and_call_original

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(mutation_response['workflow']['id']).to eq("gid://gitlab/Ai::DuoWorkflows::Workflow/#{workflow.id}")
      expect(mutation_response['workflow']['projectId']).to eq("gid://gitlab/Project/#{project.id}")
      expect(mutation_response['workflow']['namespaceId']).to be_nil
      expect(mutation_response['errors']).to be_empty
    end
  end
end
