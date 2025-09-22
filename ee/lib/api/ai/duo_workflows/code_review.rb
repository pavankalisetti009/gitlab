# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class CodeReview < ::API::Base
        include PaginationParams
        include APIGuard

        allow_access_with_scope :ai_workflows

        feature_category :code_review_workflow

        before do
          authenticate!
          set_current_organization
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
