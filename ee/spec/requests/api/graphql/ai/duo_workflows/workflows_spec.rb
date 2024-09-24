# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Duo Workflows Workflows', feature_category: :duo_workflow do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:workflows) { create_list(:duo_workflows_workflow, 3, project: project, user: user) }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id,
        userId,
        projectId,
        humanStatus,
        goal,
        createdAt,
        updatedAt
      }
    GRAPHQL
  end

  let(:current_user) { user }
  let(:query) { graphql_query_for('duoWorkflowWorkflows', nil, fields) }

  subject(:returned_workflows) { graphql_data.dig('duoWorkflowWorkflows', 'nodes') }

  context 'when user is not logged in' do
    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(returned_workflows).to be_empty
    end
  end

  context 'when the user does not have access to the project' do
    let(:current_user) { create(:user) }

    it 'returns an empty array', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_nil
      expect(returned_workflows).to be_empty
    end
  end

  context 'when the user has access to the project' do
    it 'returns the workflows', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_nil

      expect(returned_workflows).not_to be_empty
      expect(returned_workflows.length).to eq(workflows.length)
      sorted_workflows = workflows.sort_by { |w| w.id.to_s }
      returned_workflows.sort_by { |workflow| workflow['id'] }.each_with_index do |returned_workflow, i|
        expect(returned_workflow['id']).to eq(sorted_workflows[i].to_global_id.to_s)
        expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)
        expect(returned_workflow['projectId']).to eq(project.to_global_id.to_s)
        expect(returned_workflow['humanStatus']).to eq(sorted_workflows[i].human_status_name)
        expect(returned_workflow['createdAt']).to eq(sorted_workflows[i].created_at.iso8601)
        expect(returned_workflow['updatedAt']).to eq(sorted_workflows[i].updated_at.iso8601)
        expect(returned_workflow['goal']).to eq("Fix pipeline")
      end
    end
  end
end
