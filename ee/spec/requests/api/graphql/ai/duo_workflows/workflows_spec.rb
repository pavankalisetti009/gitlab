# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Duo Workflows Workflows', feature_category: :duo_workflow do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:project_2) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:workflow_without_environment) do
    create(:duo_workflows_workflow, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:workflow_with_ide_environment) do
    create(:duo_workflows_workflow, environment: :ide, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:workflow_with_web_environment) do
    create(:duo_workflows_workflow, environment: :web, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:workflows) { [workflow_without_environment, workflow_with_ide_environment, workflow_with_web_environment] }
  let_it_be(:workflows_project_2) { create_list(:duo_workflows_workflow, 2, project: project_2, user: user) }
  let_it_be(:workflows_for_different_user) { create_list(:duo_workflows_workflow, 4, project: project) }
  let(:all_project_workflows) { workflows + workflows_project_2 }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id,
        userId,
        projectId,
        humanStatus,
        goal,
        workflowDefinition,
        environment,
        createdAt,
        updatedAt
      }
    GRAPHQL
  end

  let(:variables) { nil }
  let(:current_user) { user }
  let(:query) { graphql_query_for('duoWorkflowWorkflows', variables, fields) }

  subject(:returned_workflows) { graphql_data.dig('duoWorkflowWorkflows', 'nodes') }

  context 'when duo workflow is not available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project_2, :duo_workflow).and_return(false)
    end

    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(returned_workflows).to be_empty
    end
  end

  context 'when duo workflow is available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project_2, :duo_workflow).and_return(true)
    end

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
      it 'returns the workflows' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil

        expect(returned_workflows).not_to be_empty
        expect(returned_workflows.length).to eq(all_project_workflows.length)
        all_project_workflows_by_id = all_project_workflows.index_by { |w| w.to_global_id.to_s }
        returned_workflows.each do |returned_workflow|
          matching_workflow = all_project_workflows_by_id[returned_workflow['id']]
          expect(matching_workflow).not_to be_nil
          expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)
          expect(returned_workflow['projectId']).to eq(matching_workflow.project.to_global_id.to_s)
          expect(returned_workflow['humanStatus']).to eq(matching_workflow.human_status_name)
          expect(returned_workflow['createdAt']).to eq(matching_workflow.created_at.iso8601)
          expect(returned_workflow['updatedAt']).to eq(matching_workflow.updated_at.iso8601)
          expect(returned_workflow['goal']).to eq("Fix pipeline")
          expect(returned_workflow['workflowDefinition']).to eq("software_development")
        end
      end

      context 'with the project_path argument' do
        let(:variables) { { project_path: project.full_path } }

        it 'returns only the workflows for that project owned by that user', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(workflows.length)
          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)
          end
        end
      end

      context 'with the environment argument' do
        context 'when environment argument is web' do
          let(:variables) { { environment: :WEB } }

          it 'returns only workflows with web environment', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(1)
            returned_workflows.each do |returned_workflow|
              expect(returned_workflow['environment']).to eq("WEB")
            end
          end
        end

        context 'when environment argument is not given' do
          let(:variables) { {} }

          it 'returns workflows independent of environment', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length)
          end
        end
      end

      context 'with the sort argument' do
        context 'when :created_asc' do
          let(:variables) { { sort: :created_asc } }

          it 'returns the workflows oldest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length)
            expect(returned_workflows.first['createdAt']).to be < returned_workflows.last['createdAt']
          end
        end

        context 'when :created_desc' do
          let(:variables) { { sort: :created_desc } }

          it 'returns the workflows latest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length)
            expect(returned_workflows.first['createdAt']).to be > returned_workflows.last['createdAt']
          end
        end
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        project.project_setting.update!(duo_features_enabled: false)
        project_2.project_setting.update!(duo_features_enabled: false)
      end

      it 'returns an empty array' do
        post_graphql(query, current_user: user)

        expect(returned_workflows).to be_empty
      end
    end
  end
end
