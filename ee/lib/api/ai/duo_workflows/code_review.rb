# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class CodeReview < ::API::Base
        include PaginationParams
        include APIGuard

        allow_access_with_scope :ai_workflows

        feature_category :code_suggestions

        before do
          authenticate!
          set_current_organization
          verify_duo_agent_platform_code_review_enabled!
          verify_composite_identity!
        end

        helpers do
          def verify_duo_agent_platform_code_review_enabled!
            return if ::Ai::DuoCodeReview.dap?(user: current_user, container: project_from_params)

            forbidden!('You are not allowed to use Duo Code Review through Duo Agent Platform')
          end

          def verify_composite_identity!
            return if valid_service_account?

            forbidden!('This endpoint can only be accessed by Duo Workflow Service')
          end

          # Ensure requests come through Duo Workflow Service via composite identity.
          # Composite identity: service account acts on behalf of human user.
          # - current_user: the human user (e.g., root)
          # - service_account_user: the service account (e.g., duo-developer)
          def valid_service_account?
            service_account = Gitlab::Auth::Identity.invert_composite_identity(current_user)
            return false unless service_account

            workflow_definition = ::Ai::Catalog::FoundationalFlow['code_review/v1']
            resolved_service_account_result = ::Ai::Catalog::ItemConsumers::ResolveServiceAccountService.new(
              container: project_from_params,
              item: workflow_definition.catalog_item
            ).execute

            return false if resolved_service_account_result.error?

            toplevel_group_service_account = resolved_service_account_result.payload.fetch(:service_account)
            toplevel_group_service_account.id == service_account.id
          end

          def project_from_params
            @project_from_params ||= find_project!(params[:project_id])
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            namespace :code_review do
              desc 'Add code review comments to a merge request' do
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
                requires :project_id, type: String,
                  desc: 'The ID or path of the project'
                requires :merge_request_iid, type: Integer,
                  desc: 'The IID of the merge request'
                requires :review_output, type: String,
                  desc: 'The review output from LLM'
              end
              post :add_comments do
                merge_request = find_project_merge_request(params[:merge_request_iid], project: project_from_params)

                result = ::Ai::DuoWorkflows::CodeReview::CreateCommentsService.new(
                  user: current_user,
                  merge_request: merge_request,
                  review_output: params[:review_output]
                ).execute

                if result.success?
                  output = { message: 'Comments added successfully' }
                  present output, with: Grape::Presenters::Presenter
                else
                  bad_request!(result.message)
                end
              end
            end
          end
        end
      end
    end
  end
end
