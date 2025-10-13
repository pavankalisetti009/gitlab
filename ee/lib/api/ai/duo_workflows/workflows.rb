# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class Workflows < ::API::Base
        include PaginationParams
        include APIGuard

        HEADERS_TO_FORWARD_AS_GRPC_METADATA = %w[X-Gitlab-Language-Server-Version X-Gitlab-Client-Type].freeze

        helpers ::API::Helpers::DuoWorkflowHelpers

        feature_category :duo_agent_platform

        before do
          authenticate!
          set_current_organization
        end

        helpers do
          def find_root_namespace
            # The IDE sends namespace data via the header, while the web agentic chat UI
            # sends it as a query param.
            # The IDE only sends the namespace_id of the project's
            # immediate group, so we have to find the root_ancestor separately.
            namespace_id = params[:root_namespace_id].presence ||
              params[:namespace_id].presence ||
              headers['X-Gitlab-Namespace-Id'].presence
            return unless namespace_id

            namespace = find_namespace(namespace_id)
            namespace&.root_ancestor
          end

          def find_user_selected_model_identifier
            # Currently, only the web agentic chat UI sends this attribute, as a query param.
            # The IDE does not yet send this attribute.
            params[:user_selected_model_identifier].presence
          end

          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
          end

          def authorize_feature_flag!
            disabled =
              case params[:workflow_definition]
              when 'chat'
                Feature.disabled?(:duo_agentic_chat, current_user)
              when nil
                Feature.disabled?(:duo_workflow, current_user) && Feature.disabled?(:duo_agentic_chat, current_user)
              else
                Feature.disabled?(:duo_workflow, current_user)
              end

            not_found! if disabled
          end

          def start_workflow_params(workflow_id, container:)
            workflow_context_service = workflow_context_generation_service(container: container)

            oauth_token_result = workflow_context_service.generate_oauth_token_with_composite_identity_support
            if oauth_token_result.error?
              render_api_error!(oauth_token_result[:message], oauth_token_result[:http_status] || :forbidden)
            end

            workflow_token_result = workflow_context_service.generate_workflow_token
            bad_request!(workflow_token_result[:message]) if workflow_token_result.error?

            {
              goal: params[:goal],
              workflow_id: workflow_id,
              workflow_oauth_token: oauth_token_result[:oauth_access_token].plaintext_token,
              workflow_service_token: workflow_token_result[:token],
              use_service_account: workflow_context_service.use_service_account?,
              source_branch: params[:source_branch],
              additional_context: params[:additional_context],
              workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user).to_json,
              shallow_clone: params.fetch(:shallow_clone, true),
              duo_agent_platform_feature_setting: workflow_context_service.duo_agent_platform_feature_setting
            }
          end

          # container is not available in the context of `/direct_access` endpoint
          def workflow_context_generation_service(container: nil)
            ::Ai::DuoWorkflows::WorkflowContextGenerationService.new(
              current_user: current_user,
              organization: container&.organization || ::Current.organization,
              workflow_definition: params[:workflow_definition],
              container: container
            )
          end

          def gitlab_oauth_token
            workflow_context_service = workflow_context_generation_service
            oauth_token_result = workflow_context_service.generate_oauth_token

            if oauth_token_result.error?
              render_api_error!(oauth_token_result[:message], oauth_token_result[:http_status] || :forbidden)
            end

            oauth_token_result[:oauth_access_token]
          end

          def duo_workflow_token
            workflow_context_service = workflow_context_generation_service
            workflow_token_result = workflow_context_service.generate_workflow_token
            bad_request!(workflow_token_result[:message]) if workflow_token_result.error?

            workflow_token_result
          end

          def duo_workflow_list_tools
            duo_workflow_list_tools_result = ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
              duo_workflow_service_url: Gitlab::DuoWorkflow::Client.url(user: current_user),
              current_user: current_user,
              secure: Gitlab::DuoWorkflow::Client.secure?
            ).list_tools
            bad_request!(duo_workflow_list_tools_result[:message]) if duo_workflow_list_tools_result[:status] == :error

            duo_workflow_list_tools_result
          end

          def create_workflow_params
            wrkf_params = declared_params(include_missing: false).except(
              :start_workflow,
              :source_branch,
              :additional_context,
              :shallow_clone
            )

            return wrkf_params unless wrkf_params[:ai_catalog_item_version_id]

            wrkf_params[:ai_catalog_item_version] = ::Ai::Catalog::ItemVersion
                                                      .find(wrkf_params.delete(:ai_catalog_item_version_id))
            wrkf_params
          end

          params :workflow_params do
            optional :project_id, type: String, desc: 'The ID or path of the workflow project',
              documentation: { example: '1' }
            optional :namespace_id, type: String, desc: 'The ID or path of the workflow namespace',
              documentation: { example: '1' }
            optional :start_workflow, type: Boolean,
              desc: 'Optional parameter to start workflow in a CI pipeline.' \
                'This feature is currently in an experimental state.',
              documentation: { example: true }
            optional :goal, type: String, desc: 'Goal of the workflow',
              documentation: { example: 'Fix pipeline for merge request 1 in project 1' }
            optional :agent_privileges, type: [Integer], desc: 'The actions the agent is allowed to perform',
              documentation: { example: [1] }
            optional :pre_approved_agent_privileges, type: [Integer],
              desc: 'The actions the agent can perform without asking for approval',
              documentation: { example: [1] }
            optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
              documentation: { example: 'software_developer' }
            optional :allow_agent_to_request_user, type: Boolean,
              desc: 'When this is enabled Duo Agent Platform may stop to ask the user questions before proceeding. ' \
                'When it is disabled Duo Agent Platform will always just run through the workflow without ever ' \
                'asking for user input. Defaults to true.',
              documentation: { example: true }
            optional :image, type: String, desc: 'Container image to use for running the workflow in CI pipeline.',
              documentation: { example: 'registry.gitlab.com/gitlab-org/duo-workflow/custom-image:latest' }
            optional :source_branch, type: String,
              desc: 'Source branch for the CI pipeline. Uses default branch when not specified.',
              documentation: { example: 'main' }
            optional :environment, type: String,
              values: ::Ai::DuoWorkflows::Workflow.environments.keys.map(&:to_s),
              desc: 'Environment for the workflow.',
              documentation: { example: 'web' }
            optional :ai_catalog_item_version_id, type: Integer,
              desc: 'The ID of AI Catalog ItemVersion that sourced flow config used by the workflow.',
              documentation: { example: 1 }
            optional :additional_context, type: Array[Hash],
              values: ->(array_entry) {
                array_entry.is_a?(Hash) &&
                  array_entry.key?('Category') &&
                  array_entry.key?('Content') &&
                  array_entry['Category'].is_a?(String) &&
                  array_entry['Content'].is_a?(String)
              },
              desc: 'Additional Context required by the Flow, in JSON format. Contains an array of context details, ' \
                'where each detail is a Hash with a minimum of "Category" and "Content" keys.',
              documentation: {
                example: '[{"Category": "agent_user_environment", "Content": "{\"merge_request_url\": ' \
                  'https://gitlab.com/project/-/merge_requests/1\"}", "Metadata": "{}"}]'
              }
            optional :shallow_clone, type: Boolean,
              desc: 'Whether or not the workflow should use a shallow clone of the repository during its execution.  ' \
                'Defaults to true.',
              default: true,
              documentation: { example: true }
            exactly_one_of :project_id, :namespace_id
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            resources :direct_access do
              desc 'Connection details for accessing Duo Agent Platform Service directly' do
                detail 'This feature is experimental.'
                success code: 201
                failure [
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' },
                  { code: 429, message: 'Too many requests' }
                ]
              end

              params do
                optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
                  documentation: { example: 'software_developer' }
              end

              post do
                authorize_feature_flag!

                check_rate_limit!(:duo_workflow_direct_access, scope: current_user)

                oauth_token = gitlab_oauth_token
                workflow_token = duo_workflow_token

                access = {
                  gitlab_rails: {
                    base_url: Gitlab.config.gitlab.url,
                    token: oauth_token.plaintext_token,
                    token_expires_at: oauth_token.expires_at
                  },
                  duo_workflow_service: {
                    base_url: Gitlab::DuoWorkflow::Client.url(user: current_user),
                    token: workflow_token[:token],
                    token_expires_at: workflow_token[:expires_at],
                    headers: Gitlab::DuoWorkflow::Client.headers(user: current_user),
                    secure: Gitlab::DuoWorkflow::Client.secure?
                  },
                  duo_workflow_executor: {
                    executor_binary_url: Gitlab::DuoWorkflow::Executor.executor_binary_url,
                    executor_binary_urls: Gitlab::DuoWorkflow::Executor.executor_binary_urls,
                    version: Gitlab::DuoWorkflow::Executor.version
                  },
                  workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user)
                }

                present access, with: Grape::Presenters::Presenter
              end
            end

            resources :list_tools do
              desc 'List Duo Agent Platform tools' do
                detail 'This feature is experimental.'
                success code: 200
                failure [
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' },
                  { code: 429, message: 'Too many requests' }
                ]
              end

              params do
                optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
                  documentation: { example: 'software_developer' }
              end

              get do
                authorize_feature_flag!

                check_rate_limit!(:duo_workflow_direct_access, scope: current_user)

                result = duo_workflow_list_tools

                present(result.payload, with: Grape::Presenters::Presenter)
              end
            end

            get :ws do
              authorize_feature_flag!

              require_gitlab_workhorse!

              status :ok
              content_type Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE

              push_feature_flags
              root_namespace = find_root_namespace

              model_metadata_headers = ::Ai::DuoWorkflows::DuoAgentPlatformModelMetadataService.new(
                root_namespace: root_namespace,
                current_user: current_user,
                user_selected_model_identifier: find_user_selected_model_identifier
              ).execute

              feature_setting = ::Ai::FeatureSettingSelectionService
                                  .new(current_user, :duo_agent_platform, root_namespace)
                                  .execute.payload

              grpc_headers = Gitlab::DuoWorkflow::Client.cloud_connector_headers(user: current_user).merge(
                'x-gitlab-oauth-token' => gitlab_oauth_token.plaintext_token,
                'x-gitlab-unidirectional-streaming' => 'enabled'
              ).merge(model_metadata_headers)

              grpc_headers['x-gitlab-project-id'] ||= params[:project_id].presence
              grpc_headers['x-gitlab-root-namespace-id'] = root_namespace&.id&.to_s
              grpc_headers['x-gitlab-namespace-id'] ||= params[:namespace_id].presence ||
                grpc_headers['X-Gitlab-Namespace-Id'].presence ||
                grpc_headers['x-gitlab-root-namespace-id']

              HEADERS_TO_FORWARD_AS_GRPC_METADATA.each do |header|
                header_value = headers[header]

                grpc_headers[header.downcase] = header_value if header_value.present?
              end

              {
                DuoWorkflow: {
                  Headers: grpc_headers,
                  ServiceURI: Gitlab::DuoWorkflow::Client.url_for(feature_setting: feature_setting, user: current_user),
                  Secure: Gitlab::DuoWorkflow::Client.secure?
                }
              }
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
                ::Gitlab::QueryLimiting.disable!(
                  'https://gitlab.com/gitlab-org/gitlab/-/issues/566195', new_threshold: 107
                )

                container = if params[:project_id]
                              find_project!(params[:project_id])
                            elsif params[:namespace_id]
                              find_namespace!(params[:namespace_id])
                            end

                service = ::Ai::DuoWorkflows::CreateWorkflowService.new(
                  container: container, current_user: current_user, params: create_workflow_params)

                result = service.execute

                forbidden!(result.message) if result.error? && result.http_status == :forbidden
                not_found!(result.message) if result.error? && result.http_status == :not_found
                bad_request!(result[:message]) if result[:status] == :error

                push_ai_gateway_headers

                if params[:start_workflow].present?
                  response = ::Ai::DuoWorkflows::StartWorkflowService.new(
                    workflow: result[:workflow],
                    params: start_workflow_params(result[:workflow].id, container: container)
                  ).execute

                  if response.error?
                    status_code = case response.reason
                                  when :unprocessable_entity
                                    :unprocessable_entity
                                  when :feature_unavailable, :service_account_error
                                    :forbidden
                                  when :workload_failure
                                    :unprocessable_entity
                                  else
                                    :internal_server_error
                                  end
                    render_api_error!(response.message, status_code)
                  else
                    workload_id = response.payload && response.payload[:workload_id]
                    message = response.message
                  end
                end

                present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                  workload: { id: workload_id, message: message }
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
