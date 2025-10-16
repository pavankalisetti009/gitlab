# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Duo Workflow Events', feature_category: :agent_foundations do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:another_project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: [project, another_project]) }
  let_it_be(:another_user) { create(:user, developer_of: project) }
  let_it_be(:checkpoints) { create_list(:duo_workflows_checkpoint, 3, project: project) }

  let_it_be(:ide_workflow) do
    create(:duo_workflows_workflow, project: project, user: user, checkpoints: checkpoints, environment: :ide)
  end

  let_it_be(:remote_workflow) do
    create(:duo_workflows_workflow, project: project, user: user,
      checkpoints: create_list(:duo_workflows_checkpoint, 2, project: project), environment: :web,
      workflow_definition: :convert_to_gitlab_ci)
  end

  let_it_be(:remote_workflow_for_another_project) do
    create(:duo_workflows_workflow, project: another_project, user: user,
      checkpoints: create_list(:duo_workflows_checkpoint, 2, project: another_project), environment: :web,
      workflow_definition: :convert_to_gitlab_ci)
  end

  let(:fields) do
    <<~GRAPHQL
      edges {
        node {
          timestamp,
          errors,
          checkpoint,
          metadata,
          parentTimestamp,
          workflowGoal,
          workflowDefinition,
          threadTs,
          parentTs
        }
    }
    GRAPHQL
  end

  let(:arguments) { { workflowId: global_id_of(ide_workflow) } }
  let(:query) { graphql_query_for('duoWorkflowEvents', arguments, fields) }

  subject(:event_nodes) { graphql_data.dig('duoWorkflowEvents', 'edges') }

  context 'when user is not logged in' do
    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(event_nodes).to be_empty
    end
  end

  context 'when user is logged in' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf  -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    it 'returns user messages' do
      post_graphql(query, current_user: user)

      expect(event_nodes).not_to be_empty
      event_nodes.sort_by { |event_node| event_node['node']['timestamp'] }.each_with_index do |event_node, i|
        event = event_node['node']
        expect(event['errors']).to eq([])
        expect(event['checkpoint']).to eq(checkpoints[i].checkpoint.to_json)
        expect(event['metadata']).to eq(checkpoints[i].metadata.to_json)
        expect(event['timestamp']).to eq(checkpoints[i].thread_ts)
        expect(event['parentTimestamp']).to eq(checkpoints[i].parent_ts)
        expect(event['threadTs']).to eq(checkpoints[i].thread_ts)
        expect(event['parentTs']).to eq(checkpoints[i].parent_ts)
        expect(event['workflowGoal']).to eq("Fix pipeline")
        expect(event['workflowDefinition']).to eq("software_development")
      end
    end
  end

  context 'when project_path is specified' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(another_project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf  -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    let_it_be(:project_fields) { project_fields_for_workflow(remote_workflow) }
    let_it_be(:project_query) { graphql_query_for('project', { full_path: project.full_path }, project_fields) }

    it 'returns a users remote flow events for the project' do
      post_graphql(project_query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events.length).to eq(2)
    end

    it 'returns another users remote flow events for the project' do
      post_graphql(project_query, current_user: another_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events.length).to eq(2)
    end

    it "does not return another users ide flow events for the project" do
      project_fields_ide = project_fields_for_workflow(ide_workflow)
      ide_workflow_project_query = graphql_query_for('project', { full_path: project.full_path }, project_fields_ide)
      post_graphql(ide_workflow_project_query, current_user: another_user)

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events).to be_empty
    end

    it 'returns empty array if workflow is not in project' do
      project_fields = project_fields_for_workflow(remote_workflow)
      another_project_query = graphql_query_for('project', { full_path: another_project.full_path }, project_fields)
      post_graphql(another_project_query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events).to be_empty
    end
  end

  context 'when project_path is specified and user is not a member of the project' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(another_project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf  -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    let_it_be(:project_fields) { project_fields_for_workflow(remote_workflow_for_another_project) }
    let_it_be(:project_query) { graphql_query_for('project', { full_path: another_project.full_path }, project_fields) }

    it 'returns an empty array for a remote flow' do
      post_graphql(project_query, current_user: another_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events).to be_nil
    end
  end

  def project_fields_for_workflow(workflow)
    <<~GRAPHQL
      duoWorkflowEvents(workflowId: "#{workflow.to_global_id}") {
        nodes {
          checkpoint
        }
      }
    GRAPHQL
  end
end
