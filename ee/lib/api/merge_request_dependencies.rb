# frozen_string_literal: true

module API
  class MergeRequestDependencies < ::API::Base
    include PaginationParams

    feature_category :code_review_workflow

    helpers do
      def find_block(merge_request)
        merge_request.blocks_as_blockee.find(params[:block_id])
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get all merge request dependencies' do
        success ::API::Entities::MergeRequestDependency
        tags %w[merge_requests]
        is_array true
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        use :pagination
      end
      route_setting :authorization, permissions: :read_merge_request_dependency, boundary_type: :project
      get ":id/merge_requests/:merge_request_iid/blocks" do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        present paginate(merge_request.blocks_as_blockee), with: ::API::Entities::MergeRequestDependency,
          current_user: current_user
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        requires :block_id, type: Integer, desc: 'The ID of the merge request dependency'
      end
      route_setting :authorization, permissions: :read_merge_request_dependency, boundary_type: :project
      get ":id/merge_requests/:merge_request_iid/blocks/:block_id", urgency: :low do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        present find_block(merge_request),
          with: ::API::Entities::MergeRequestDependency, current_user: current_user
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        requires :block_id, type: Integer, desc: 'The ID of the merge request dependency'
      end
      route_setting :authorization, permissions: :delete_merge_request_dependency, boundary_type: :project
      delete ":id/merge_requests/:merge_request_iid/blocks/:block_id", urgency: :low do
        merge_request = find_merge_request_with_access(params[:merge_request_iid], :update_merge_request)
        block = find_block(merge_request)

        authorize! :read_merge_request, block.blocking_merge_request

        destroy_conditionally!(block)
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal IID of the blocked merge request'
        optional :blocking_merge_request_id, type: Integer, desc: 'The global ID of the blocking merge request'
        optional :blocking_merge_request_iid, type: Integer, desc: 'The IID of the blocking merge request'
        optional :blocking_project_id, types: [String, Integer],
          desc: 'The ID or URL-encoded path of the project containing the blocking merge request ' \
            '(defaults to current project)'
        mutually_exclusive :blocking_merge_request_id, :blocking_merge_request_iid
        exactly_one_of :blocking_merge_request_id, :blocking_merge_request_iid
      end
      route_setting :authorization, permissions: :create_merge_request_dependency, boundary_type: :project
      post ":id/merge_requests/:merge_request_iid/blocks", urgency: :low do
        merge_request = find_project_merge_request(params[:merge_request_iid])

        blocking_merge_request_id =
          if params[:blocking_merge_request_id]
            params[:blocking_merge_request_id]
          else
            # IID-based lookup with optional project context
            blocking_project = params[:blocking_project_id] ? find_project!(params[:blocking_project_id]) : user_project
            blocking_merge_request = blocking_project.merge_requests.find_by_iid(params[:blocking_merge_request_iid])
            blocking_merge_request&.id
          end

        result =
          ::MergeRequests::CreateBlockService
            .new(
              merge_request: merge_request,
              user: current_user,
              blocking_merge_request_id: blocking_merge_request_id
            ).execute

        if result.success?
          present result.payload[:merge_request_block], with: ::API::Entities::MergeRequestDependency, current_user:
            current_user
        else
          render_api_error!(result.message, result.reason)
        end
      end

      desc 'Get all merge requests are blockees for this merge request' do
        success ::API::Entities::MergeRequestDependency
        tags %w[merge_requests]
        is_array true
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        use :pagination
      end
      route_setting :authorization, permissions: :read_merge_request_dependency, boundary_type: :project
      get ":id/merge_requests/:merge_request_iid/blockees" do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        blockees = merge_request.blocks_as_blocker

        present paginate(blockees), with: ::API::Entities::MergeRequestDependency, current_user: current_user
      end
    end
  end
end
