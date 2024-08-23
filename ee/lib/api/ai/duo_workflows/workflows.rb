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

                gitlab_oauth_token_result = ::Ai::DuoWorkflows::CreateOauthAccessTokenService.new(
                  current_user: current_user).execute

                if gitlab_oauth_token_result[:status] == :error
                  render_api_error!(gitlab_oauth_token_result[:message], gitlab_oauth_token_result[:http_status])
                end

                duo_workflow_token_result = ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
                  duo_workflow_service_url: Gitlab::DuoWorkflow::Client.url,
                  current_user: current_user,
                  secure: Gitlab::DuoWorkflow::Client.secure?
                ).generate_token

                bad_request!(duo_workflow_token_result[:message]) if duo_workflow_token_result[:status] == :error

                access = {
                  gitlab_rails: {
                    base_url: Gitlab.config.gitlab.url,
                    token: gitlab_oauth_token_result[:oauth_access_token].plaintext_token
                  },
                  duo_workflow_service: {
                    base_url: Gitlab::DuoWorkflow::Client.url,
                    token: duo_workflow_token_result[:token],
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
              post do
                project = find_project!(params[:project_id])
                authorize_run_workflows!(project)

                service = ::Ai::DuoWorkflows::CreateWorkflowService.new(project: project, current_user: current_user,
                  params: declared_params(include_missing: false))

                result = service.execute

                bad_request!(result[:message]) if result[:status] == :error

                present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow
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
            end
          end
        end
      end
    end
  end
end
