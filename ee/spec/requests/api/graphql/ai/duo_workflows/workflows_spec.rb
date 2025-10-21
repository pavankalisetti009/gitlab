# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Many cases to deal with here.
RSpec.describe 'Querying Duo Workflows Workflows', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:ai_settings) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be(:group) { create(:group, ai_settings: ai_settings) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:project_2) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:another_user) { create(:user, developer_of: group) }
  let_it_be(:workflow_without_environment) do
    create(:duo_workflows_workflow, project: project, user: user, created_at: 1.day.ago).tap do |workflow|
      workload = create(:ci_workload, project: project)
      workflow.workflows_workloads.create!(workload: workload, project: project)
    end
  end

  let_it_be(:ai_catalog_item_version) { create(:ai_catalog_agent_version) }

  let_it_be(:workflow_with_ide_environment) do
    create(:duo_workflows_workflow, environment: :ide, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:workflow_with_web_environment) do
    create(:duo_workflows_workflow, environment: :web, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:remote_execution_workflow_another_user) do
    create(:duo_workflows_workflow, project: project, user: another_user, environment: :web,
      workflow_definition: :convert_to_gitlab_ci)
  end

  let_it_be(:archived_workflow) do
    create(:duo_workflows_workflow,
      project: project,
      user: user,
      created_at: (Ai::DuoWorkflows::CHECKPOINT_RETENTION_DAYS + 1).days.ago)
  end

  let_it_be(:stalled_workflow) do
    workflow = create(:duo_workflows_workflow, project: project, user: user)
    workflow.start!
    workflow
  end

  let_it_be(:non_stalled_workflow_with_checkpoint) do
    workflow = create(:duo_workflows_workflow, project: project, user: user)
    workflow.start!
    create(:duo_workflows_checkpoint, workflow: workflow, project: workflow.project)
    workflow
  end

  let_it_be(:namespace_level_workflow) do
    create(:duo_workflows_workflow, :agentic_chat, namespace: group, user: user)
  end

  let_it_be(:workflows) do
    [
      workflow_without_environment,
      workflow_with_ide_environment,
      workflow_with_web_environment,
      archived_workflow,
      stalled_workflow,
      non_stalled_workflow_with_checkpoint
    ]
  end

  let_it_be(:workflows_project_2) do
    create_list(:duo_workflows_workflow, 2, project: project_2, user: user,
      ai_catalog_item_version: ai_catalog_item_version)
  end

  let_it_be(:workflows_for_different_user) do
    create_list(:duo_workflows_workflow, 4, project: project, user: another_user)
  end

  let(:all_project_workflows) { workflows + workflows_project_2 }
  let(:all_namespace_workflows) { [namespace_level_workflow] }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id,
        userId,
        projectId,
        project {
          id
          name
        },
        namespaceId,
        namespace {
          id
          name
        },
        humanStatus,
        goal,
        workflowDefinition,
        environment,
        createdAt,
        updatedAt,
        status,
        statusName,
        statusGroup,
        agentPrivilegesNames,
        preApprovedAgentPrivilegesNames,
        mcpEnabled
        allowAgentToRequestUser
        archived
        stalled
        firstCheckpoint {
          checkpoint
          metadata
          timestamp
          workflowStatus
        }
        lastExecutorLogsUrl
        aiCatalogItemVersionId
      }
    GRAPHQL
  end

  let(:variables) { nil }
  let(:current_user) { user }
  let(:query) { graphql_query_for('duoWorkflowWorkflows', variables, fields) }

  # Create a checkpoint for the first workflow to test the firstCheckpoint field
  let_it_be(:checkpoint) do
    workflow = workflows.first
    create(:duo_workflows_checkpoint, workflow: workflow, project: workflow.project)
  end

  before do
    # Allow StageCheck for any project
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(false)
  end

  subject(:returned_workflows) { graphql_data.dig('duoWorkflowWorkflows', 'nodes') }

  context 'when duo workflow is not available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(false)
    end

    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(returned_workflows).to be_empty
    end
  end

  context 'when duo workflow is available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(true)
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

    context 'when the user has access to the project and is allowed to use duo_agent_platform' do
      before do
        # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
        allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
        # rubocop:enable RSpec/AnyInstanceOf
      end

      it 'returns the workflows' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil

        expect(returned_workflows).not_to be_empty
        expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
        all_workflows_by_id = (all_project_workflows + all_namespace_workflows).index_by { |w| w.to_global_id.to_s }
        returned_workflows.each do |returned_workflow|
          matching_workflow = all_workflows_by_id[returned_workflow['id']]
          expect(matching_workflow).not_to be_nil
          expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)

          if matching_workflow.project_level?
            expect(returned_workflow['projectId']).to eq(matching_workflow.project.to_global_id.to_s)
            expect(returned_workflow['project']['id']).to eq(matching_workflow.project.to_global_id.to_s)
            expect(returned_workflow['project']['name']).to eq(matching_workflow.project.name)
            expect(returned_workflow['namespaceId']).to be_nil
            expect(returned_workflow['namespace']).to be_nil
          elsif matching_workflow.namespace_level?
            expect(returned_workflow['projectId']).to be_nil
            expect(returned_workflow['project']).to be_nil
            expect(returned_workflow['namespaceId'])
              .to eq("gid://gitlab/Types::Namespace/#{matching_workflow.namespace.id}")
            expect(returned_workflow['namespace']['id']).to eq(matching_workflow.namespace.to_global_id.to_s)
            expect(returned_workflow['namespace']['name']).to eq(matching_workflow.namespace.name)
          end

          expect(returned_workflow['humanStatus']).to eq(matching_workflow.human_status_name)
          expect(returned_workflow['createdAt']).to eq(matching_workflow.created_at.iso8601)
          expect(returned_workflow['updatedAt']).to eq(matching_workflow.updated_at.iso8601)
          expect(returned_workflow['goal']).to eq("Fix pipeline")
          expect(returned_workflow['workflowDefinition']).to eq(matching_workflow.workflow_definition)
          expected_status = case matching_workflow
                            when stalled_workflow, non_stalled_workflow_with_checkpoint
                              "RUNNING"
                            else
                              "CREATED"
                            end
          expect(returned_workflow['status']).to eq(expected_status)
          expect(returned_workflow['statusName']).to eq(matching_workflow.status_name.to_s)
          expect(returned_workflow['statusGroup']).to eq(matching_workflow.status_group.to_s.upcase)
          expect(returned_workflow['agentPrivilegesNames']).to eq(["read_write_files"])
          expect(returned_workflow['preApprovedAgentPrivilegesNames']).to eq([])
          expect(returned_workflow['mcpEnabled']).to eq(matching_workflow.mcp_enabled?)
          expect(returned_workflow['allowAgentToRequestUser']).to eq(matching_workflow.allow_agent_to_request_user)
          expect(returned_workflow['lastExecutorLogsUrl']).to eq(matching_workflow.last_executor_logs_url)
          expect(returned_workflow['aiCatalogItemVersionId']).to eq(
            matching_workflow.ai_catalog_item_version&.to_global_id&.to_s
          )

          expect(returned_workflow).to have_key('firstCheckpoint')
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

      context 'when scoped under a project' do
        let_it_be(:project_fields) do
          <<~GRAPHQL
            duoWorkflowWorkflows {
              nodes {
                id
              }
            }
          GRAPHQL
        end

        let_it_be(:project_query) { graphql_query_for('project', { full_path: project.full_path }, project_fields) }

        it 'returns .from_pipeline workflows for the project', :aggregate_failures do
          post_graphql(project_query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          project_workflows = graphql_data.dig("project", "duoWorkflowWorkflows", "nodes")
          expect(project_workflows.length).to eq(2)

          expected_workflows = Ai::DuoWorkflows::Workflow.for_project(project).from_pipeline
          expected_global_ids = expected_workflows.map { |workflow| workflow.to_global_id.to_s }
          project_workflows_ids = project_workflows.pluck("id")

          expect(expected_global_ids).to match_array(project_workflows_ids)
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

            expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
          end
        end
      end

      context 'with the workflow_id argument' do
        let(:specific_workflow) { workflows.first }
        let(:variables) { { workflow_id: specific_workflow.to_global_id.to_s } }

        before do
          # Ensure the checkpoint is associated with the specific workflow
          specific_workflow.reload
        end

        it 'returns only the specified workflow', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(specific_workflow.to_global_id.to_s)
          expect(returned_workflows.first['userId']).to eq(user.to_global_id.to_s)
          expect(returned_workflows.first['projectId']).to eq(specific_workflow.project.to_global_id.to_s)
          expect(returned_workflows.first['project']['id']).to eq(specific_workflow.project.to_global_id.to_s)
          expect(returned_workflows.first['project']['name']).to eq(specific_workflow.project.name)
          expect(returned_workflows.first['namespaceId']).to be_nil
          expect(returned_workflows.first['namespace']).to be_nil
          expect(returned_workflows.first['goal']).to eq("Fix pipeline")
          expect(returned_workflows.first['workflowDefinition']).to eq("software_development")
          expect(returned_workflows.first['status']).to eq("CREATED")
          expect(returned_workflows.first['statusName']).to eq(specific_workflow.status_name.to_s)
          expect(returned_workflows.first['agentPrivilegesNames']).to eq(["read_write_files"])
          expect(returned_workflows.first['preApprovedAgentPrivilegesNames']).to eq([])
          expect(returned_workflows.first['mcpEnabled']).to eq(
            specific_workflow.project.root_ancestor.duo_workflow_mcp_enabled)
          expect(returned_workflows.first['allowAgentToRequestUser']).to eq(
            specific_workflow.allow_agent_to_request_user
          )
          expect(returned_workflows.first['lastExecutorLogsUrl']).not_to be_nil
          expect(returned_workflows.first['lastExecutorLogsUrl']).to eq(
            specific_workflow.last_executor_logs_url
          )
          expect(returned_workflows.first['aiCatalogItemVersionId']).to eq(
            specific_workflow.ai_catalog_item_version&.to_global_id&.to_s
          )
          expect(returned_workflows.first).to have_key('firstCheckpoint')
        end

        context 'when the user does not have access to the workflow' do
          let(:specific_workflow) { workflows_for_different_user.first }
          let(:current_user) { create(:user) }

          it 'returns a permission error', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error_message = json_response['errors'].first['message']
            expect(error_message).to eq("You don't have permission to access this workflow")
          end
        end

        context 'when the workflow does not exist' do
          let(:variables) { { workflow_id: "gid://gitlab/Ai::DuoWorkflows::Workflow/#{non_existent_record_id}" } }
          let(:non_existent_record_id) { 999999 }

          it 'returns a resource not available error', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error_message = json_response['errors'].first['message']
            expect(error_message).to eq('Workflow not found')
          end
        end

        context 'with namespace-level workflow' do
          let(:variables) { { workflow_id: namespace_level_workflow.to_global_id.to_s } }

          it 'returns only the specified workflow', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(1)
            expect(returned_workflows.first['id']).to eq(namespace_level_workflow.to_global_id.to_s)
            expect(returned_workflows.first['userId']).to eq(user.to_global_id.to_s)
            expect(returned_workflows.first['projectId']).to be_nil
            expect(returned_workflows.first['project']).to be_nil
            expect(returned_workflows.first['namespaceId'])
              .to eq("gid://gitlab/Types::Namespace/#{namespace_level_workflow.namespace.id}")
            expect(returned_workflows.first['namespace']['id'])
              .to eq(namespace_level_workflow.namespace.to_global_id.to_s)
            expect(returned_workflows.first['namespace']['name']).to eq(namespace_level_workflow.namespace.name)
          end
        end
      end

      context 'with the sort argument' do
        context 'when CREATED_ASC' do
          let(:variables) { { sort: :CREATED_ASC } }

          it 'returns the workflows oldest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
            expect(returned_workflows.first['createdAt']).to be < returned_workflows.last['createdAt']
          end
        end

        context 'when CREATED_DESC' do
          let(:variables) { { sort: :CREATED_DESC } }

          it 'returns the workflows latest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
            expect(returned_workflows.first['createdAt']).to be > returned_workflows.last['createdAt']
          end
        end

        context 'when STATUS_ASC' do
          let(:variables) { { sort: :STATUS_ASC } }

          it 'returns the workflows ordered by status ascending', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            statuses = returned_workflows.pluck('status')
            expect(statuses).to eq(%w[
              CREATED CREATED CREATED
              CREATED CREATED CREATED
              CREATED RUNNING RUNNING
            ])
          end
        end

        context 'when STATUS_DESC' do
          let(:variables) { { sort: :STATUS_DESC } }

          it 'returns the workflows ordered by status descending', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            statuses = returned_workflows.pluck('status')
            expect(statuses).to eq(%w[
              RUNNING RUNNING CREATED
              CREATED CREATED CREATED
              CREATED CREATED CREATED
            ])
          end
        end
      end

      context 'with the type argument' do
        let(:variables) { { type: 'software_development' } }

        it 'returns only workflows with the specified type', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).to eq('software_development')
          end
        end
      end

      context 'with the search argument' do
        let(:variables) { { search: 'soft devel' } }

        it 'returns only workflows matching the seach criteria', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).to eq('software_development')
          end
        end
      end

      context 'with the status_group argument' do
        let(:variables) { { statusGroup: :ACTIVE } }

        it 'returns only workflows with in that status group', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['statusGroup']).to eq('ACTIVE')
          end
        end
      end

      context 'with the exclude_types argument' do
        let(:variables) { { exclude_types: %w[chat] } }

        it 'excludes workflows with the specified types', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).not_to eq('chat')
          end
        end
      end

      context 'with multiple exclude_types' do
        let(:variables) { { exclude_types: %w[chat convert_to_gitlab_ci] } }

        it 'excludes workflows with any of the specified types', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).not_to be_in(%w[chat convert_to_gitlab_ci])
          end
        end
      end

      context 'with both type and exclude_types arguments' do
        context 'when type and exclude_types are different' do
          let(:variables) { { type: 'software_development', exclude_types: %w[chat] } }

          it 'applies both filters correctly', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows).not_to be_empty

            returned_workflows.each do |returned_workflow|
              expect(returned_workflow['workflowDefinition']).to eq('software_development')
              expect(returned_workflow['workflowDefinition']).not_to eq('chat')
            end
          end
        end

        context 'when type matches one of exclude_types' do
          let(:variables) { { type: 'software_development', exclude_types: %w[chat software_development] } }

          it 'returns an empty array', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil
            expect(returned_workflows).to be_empty
          end
        end

        context 'when type is different from all exclude_types' do
          let(:variables) { { type: 'software_development', exclude_types: %w[chat convert_to_gitlab_ci] } }

          it 'applies all filters correctly', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows).not_to be_empty

            returned_workflows.each do |returned_workflow|
              expect(returned_workflow['workflowDefinition']).to eq('software_development')
              expect(returned_workflow['workflowDefinition']).not_to be_in(%w[chat convert_to_gitlab_ci])
            end
          end
        end
      end

      context 'with archived and stalled fields' do
        it 'returns the correct archived and stalled values', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          returned_workflows_by_id = returned_workflows.index_by { |w| w['id'] }

          # Check archived workflow
          archived_result = returned_workflows_by_id[archived_workflow.to_global_id.to_s]
          expect(archived_result).not_to be_nil
          expect(archived_result['archived']).to be(true)
          expect(archived_result['stalled']).to be(false) # archived workflows in created state are not stalled

          # Check stalled workflow (running state with no checkpoints)
          stalled_result = returned_workflows_by_id[stalled_workflow.to_global_id.to_s]
          expect(stalled_result).not_to be_nil
          expect(stalled_result['archived']).to be(false)
          expect(stalled_result['stalled']).to be(true)

          # Check non-stalled workflow with checkpoint
          non_stalled_result = returned_workflows_by_id[non_stalled_workflow_with_checkpoint.to_global_id.to_s]
          expect(non_stalled_result).not_to be_nil
          expect(non_stalled_result['archived']).to be(false)
          expect(non_stalled_result['stalled']).to be(false)

          # Check regular workflows (not archived, in created state so not stalled)
          [workflow_without_environment, workflow_with_ide_environment,
            workflow_with_web_environment].each do |workflow|
            result = returned_workflows_by_id[workflow.to_global_id.to_s]
            expect(result).not_to be_nil
            expect(result['archived']).to be(false)
            expect(result['stalled']).to be(false)
          end
        end
      end

      context 'with the workflow_id argument for archived workflow' do
        let(:variables) { { workflow_id: archived_workflow.to_global_id.to_s } }

        it 'returns the archived workflow with correct archived status', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(archived_workflow.to_global_id.to_s)
          expect(returned_workflows.first['archived']).to be(true)
          expect(returned_workflows.first['stalled']).to be(false)
        end
      end

      context 'with the workflow_id argument for stalled workflow' do
        let(:variables) { { workflow_id: stalled_workflow.to_global_id.to_s } }

        it 'returns the stalled workflow with correct stalled status', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(stalled_workflow.to_global_id.to_s)
          expect(returned_workflows.first['archived']).to be(false)
          expect(returned_workflows.first['stalled']).to be(true)
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
# rubocop:enable RSpec/MultipleMemoizedHelpers
