# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class Workflows < ::API::Base
        include PaginationParams
        include APIGuard

        feature_category :duo_workflow

        before { authenticate! }

        allow_access_with_scope :ai_workflows

        helpers do
          def find_workflow!(id)
            ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, id)
          end

          def authorize_run_workflows!(project)
            return if can?(current_user, :duo_workflow, project)

            forbidden!
          end

          def start_workflow_params(workflow_id)
            {
              goal: params[:goal],
              workflow_id: workflow_id,
              workflow_oauth_token: gitlab_oauth_token,
              workflow_service_token: duo_workflow_token
            }
          end

          def gitlab_oauth_token
            gitlab_oauth_token_result = ::Ai::DuoWorkflows::CreateOauthAccessTokenService.new(
              current_user: current_user).execute

            if gitlab_oauth_token_result[:status] == :error
              render_api_error!(gitlab_oauth_token_result[:message], gitlab_oauth_token_result[:http_status])
            end

            gitlab_oauth_token_result[:oauth_access_token].plaintext_token
          end

          def duo_workflow_token
            duo_workflow_token_result = ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
              duo_workflow_service_url: Gitlab::DuoWorkflow::Client.url,
              current_user: current_user,
              secure: Gitlab::DuoWorkflow::Client.secure?
            ).generate_token
            bad_request!(duo_workflow_token_result[:message]) if duo_workflow_token_result[:status] == :error

            duo_workflow_token_result[:token]
          end

          def create_workflow_params
            declared_params(include_missing: false).except(
              :goal, :start_workflow
            )
          end

          def render_response(response)
            if response.success?
              status :ok
              response.payload
            else
              render_api_error!(response.message, response.reason)
            end
          end

          params :workflow_params do
            requires :project_id, type: Integer, desc: 'The ID of the workflow project', documentation: { example: '1' }
            optional :start_workflow, type: Boolean, desc: 'Optional parameter to start workflow in a CI pipeline',
              documentation: { example: true }
            optional :goal, type: String, desc: 'Goal of the workflow',
              documentation: { example: 'Fix pipeline for merge request 1 in project 1' }
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            resources :direct_access do
              desc 'Connection details for accessing Duo Workflow Service directly' do
                success code: 201
                failure [
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' },
                  { code: 429, message: 'Too many requests' }
                ]
              end

              post do
                not_found! unless Feature.enabled?('duo_workflow', current_user)

                check_rate_limit!(:duo_workflow_direct_access, scope: current_user) do
                  render_api_error!(_('This endpoint has been requested too many times. Try again later.'), 429)
                end

                access = {
                  gitlab_rails: {
                    base_url: Gitlab.config.gitlab.url,
                    token: gitlab_oauth_token
                  },
                  duo_workflow_service: {
                    base_url: Gitlab::DuoWorkflow::Client.url,
                    token: duo_workflow_token,
                    headers: Gitlab::DuoWorkflow::Client.headers(user: current_user),
                    secure: Gitlab::DuoWorkflow::Client.secure?
                  },
                  duo_workflow_executor: {
                    executor_binary_url: Gitlab::DuoWorkflow::Executor.executor_binary_url,
                    version: Gitlab::DuoWorkflow::Executor.version
                  }
                }

                present access, with: Grape::Presenters::Presenter
              end
            end

            namespace :workflows do
              desc 'creates workflow persistence' do
                success code: 200
                failure [
                  { code: 400, message: 'Validation failed' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' }
                ]
              end
              params do
                use :workflow_params
              end
              post do
                project = find_project!(params[:project_id])
                authorize_run_workflows!(project)

                service = ::Ai::DuoWorkflows::CreateWorkflowService.new(project: project, current_user: current_user,
                  params: create_workflow_params)

                result = service.execute

                bad_request!(result[:message]) if result[:status] == :error

                if params[:start_workflow].present?
                  workflow = find_workflow!(result[:workflow].id)
                  response = ::Ai::DuoWorkflows::StartWorkflowService.new(
                    workflow: workflow,
                    params: start_workflow_params(workflow.id)
                  ).execute
                  pipeline_id = response.payload && response.payload[:pipeline]
                end

                present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow, pipeline_id: pipeline_id
              end

              get '/:id' do
                workflow = find_workflow!(params[:id])

                present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow
              end

              params do
                requires :id, type: Integer, desc: 'The ID of the workflow'
                requires :thread_ts, type: String, desc: 'The thread ts'
                optional :parent_ts, type: String, desc: 'The parent ts'
                requires :checkpoint, type: Hash, desc: "Checkpoint content"
                requires :metadata, type: Hash, desc: "Checkpoint metadata"
              end
              post '/:id/checkpoints' do
                workflow = find_workflow!(params[:id])
                checkpoint_params = declared_params(include_missing: false).except(:id)
                service = ::Ai::DuoWorkflows::CreateCheckpointService.new(project: workflow.project,
                  workflow: workflow, params: checkpoint_params)
                result = service.execute

                bad_request!(result[:message]) if result[:status] == :error

                present result[:checkpoint], with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
              end

              get '/:id/checkpoints' do
                workflow = find_workflow!(params[:id])
                checkpoints = workflow.checkpoints.order(thread_ts: :desc) # rubocop:disable CodeReuse/ActiveRecord -- adding scope for order is no clearer
                present paginate(checkpoints), with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
              end

              desc 'Starts Duo Workflow execution in ci pipeline' do
                success code: 200, message: 'Pipeline execution started'
                failure [
                  { code: 400, message: 'Pipeline creation failed' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' }
                ]
              end
              params do
                requires :id, type: Integer, desc: 'The ID of the workflow', documentation: { example: '1' }
                requires :goal, type: String, desc: 'Goal of the workflow',
                  documentation: { example: 'Fix pipeline for merge request 1 in project 1' }
              end
              post '/:id/start' do
                workflow = find_workflow!(params[:id])

                response = ::Ai::DuoWorkflows::StartWorkflowService.new(
                  workflow: workflow,
                  params: start_workflow_params(workflow.id)
                ).execute
                render_response(response)
              end
            end
          end
        end
      end
    end
  end
end
