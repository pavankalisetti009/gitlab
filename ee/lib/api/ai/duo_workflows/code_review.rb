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
          not_found! unless Feature.enabled?(:duo_code_review_on_agent_platform, current_user)
          authenticate!
          set_current_organization
          verify_composite_identity!
        end

        helpers do
          def verify_composite_identity!
            service_account_user = Gitlab::Auth::Identity.invert_composite_identity(current_user)

            # Ensure requests come through Duo Workflow Service via composite identity.
            # Composite identity: service account (duo-developer) acts on behalf of human user.
            # - current_user: the human user (e.g., root)
            # - service_account_user: the service account (e.g., duo-developer)

            # This check prevents direct API calls and spoofing attacks by ensuring:
            # 1. Composite identity is active (service_account_user != current_user)
            # 2. The caller is a service account, not a regular user
            return if service_account_user != current_user && service_account_user&.service_account?

            forbidden!('This endpoint can only be accessed by Duo Workflow Service')
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
                project = find_project!(params[:project_id])
                merge_request = find_project_merge_request(params[:merge_request_iid], project: project)

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
