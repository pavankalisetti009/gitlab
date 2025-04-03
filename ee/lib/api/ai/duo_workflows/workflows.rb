# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class Workflows < ::API::Base
        include PaginationParams
        include APIGuard

        feature_category :duo_workflow

        before do
          authenticate!
          set_current_organization
        end

        helpers do
          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
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
              current_user: current_user,
              organization: ::Current.organization
            ).execute

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
            declared_params(include_missing: false).except(:start_workflow)
          end

          params :workflow_params do
            requires :project_id, type: String, desc: 'The ID or path of the workflow project',
              documentation: { example: '1' }
            optional :start_workflow, type: Boolean,
              desc: 'Optional parameter to start workflow in a CI pipeline.' \
                'This feature is currently in an experimental state.',
              documentation: { example: true }
            optional :goal, type: String, desc: 'Goal of the workflow',
              documentation: { example: 'Fix pipeline for merge request 1 in project 1' }
            optional :agent_privileges, type: [Integer], desc: 'The actions the agent is allowed to perform',
              documentation: { example: [1] }
            optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
              documentation: { example: 'software_developer' }
            optional :allow_agent_to_request_user, type: Boolean,
              desc: 'When this is enabled Duo Workflow may stop to ask the user questions before proceeding. ' \
                'When it is disabled Duo Workflow will always just run through the workflow without ever asking ' \
                'for user input. Defaults to true.',
              documentation: { example: true }
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            resources :direct_access do
              desc 'Connection details for accessing Duo Workflow Service directly' do
                detail 'This feature is experimental.'
                success code: 201
                failure [
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' },
                  { code: 429, message: 'Too many requests' }
                ]
              end

              post do
                not_found! unless Feature.enabled?(:duo_workflow, current_user)

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
                    executor_binary_urls: Gitlab::DuoWorkflow::Executor.executor_binary_urls,
                    version: Gitlab::DuoWorkflow::Executor.version
                  },
                  workflow_metadata: {
                    extended_logging: Feature.enabled?(:duo_workflow_extended_logging, current_user)
                  }
                }

                present access, with: Grape::Presenters::Presenter
              end
            end

            namespace :workflows do
              desc 'creates workflow persistence' do
                detail 'This feature is experimental.'
                success code: 200
                failure [
                  { code: 400, message: 'Validation failed' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
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
                  response = ::Ai::DuoWorkflows::StartWorkflowService.new(
                    workflow: result[:workflow],
                    params: start_workflow_params(result[:workflow].id)
                  ).execute

                  pipeline_id = response.payload && response.payload[:pipeline_id]
                  message = response.message
                end

                present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                  pipeline: { id: pipeline_id, message: message }
              end

              desc 'Get all possible agent privileges and descriptions' do
                success code: 200
                failure [
                  { code: 401, message: 'Unauthorized' }
                ]
              end
              get 'agent_privileges' do
                present ::Ai::DuoWorkflows::Workflow::AgentPrivileges,
                  with: ::API::Entities::Ai::DuoWorkflows::Workflow::AgentPrivileges
              end
            end
          end
        end
      end
    end
  end
end
