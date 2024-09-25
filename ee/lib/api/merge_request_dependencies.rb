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
        success EE::API::Entities::MergeRequestDependency
        tags %w[merge_requests]
        is_array true
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        use :pagination
      end
      get ":id/merge_requests/:merge_request_iid/blocks" do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        blocks = merge_request.blocks_as_blockee

        present paginate(blocks), with: EE::API::Entities::MergeRequestDependency
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        requires :block_id, type: Integer, desc: 'The ID of the merge request dependency'
      end
      get ":id/merge_requests/:merge_request_iid/blocks/:block_id", urgency: :low do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        present find_block(merge_request),
          with: EE::API::Entities::MergeRequestDependency
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        requires :block_id, type: Integer, desc: 'The ID of the merge request dependency'
      end
      delete ":id/merge_requests/:merge_request_iid/blocks/:block_id", urgency: :low do
        merge_request = find_merge_request_with_access(params[:merge_request_iid], :update_merge_request)
        block = find_block(merge_request)

        authorize! :read_merge_request, block.blocking_merge_request

        destroy_conditionally!(block)
      end
    end
  end
end
