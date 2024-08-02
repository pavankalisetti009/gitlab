# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::MergeRequestDependencies, 'MergeRequestDependencies', feature_category: :code_review_workflow do
  let(:user) { create(:user) }
  let!(:project) { create(:project, :repository, group: group) }
  let_it_be(:group) { create :group }
  let(:merge_request) { create(:merge_request, :unique_branches, source_project: project, author: user) }
  let(:other_merge_request) { create(:merge_request, :unique_branches, source_project: project, author: user) }
  let(:another_merge_request) { create(:merge_request, :unique_branches, source_project: project, author: user) }

  before do
    merge_request.blocks_as_blockee.create!(blocking_merge_request: other_merge_request)
    merge_request.blocks_as_blockee.create!(blocking_merge_request: another_merge_request)
    project.add_maintainer(user)
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/blocks' do
    it 'returns 200 for a valid merge request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks", user)
      merge_request_dependency = merge_request.blocks_as_blockee.first

      aggregate_failures('response') do
        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
      end

      aggregate_failures('json_response') do
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(merge_request.blocks_as_blockee.size)
        expect(json_response.first['id']).to eq(merge_request_dependency.id)
        expect(json_response.first.dig('blocking_merge_request', 'id'))
          .to eq(merge_request_dependency.blocking_merge_request.id)
        expect(json_response.first.dig('blocked_merge_request', 'id'))
          .to eq(merge_request_dependency.blocked_merge_request.id)
      end
    end

    it 'returns a 404 when merge_request id is used instead of the iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}/blocks", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/blocks", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks" }
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/blocks/:block_id' do
    let(:blocked_mr) { merge_request.blocks_as_blockee.first }

    it 'returns a 200 for a valid merge request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks/#{blocked_mr.id}", user)

      expect(response).to have_gitlab_http_status(:ok)

      aggregate_failures('json_response') do
        expect(json_response['id']).to eq(blocked_mr.id)
        expect(json_response.dig('blocking_merge_request', 'id'))
          .to eq(blocked_mr.blocking_merge_request.id)
        expect(json_response.dig('blocked_merge_request', 'id'))
          .to eq(blocked_mr.blocked_merge_request.id)
      end
    end

    it 'returns a 404 when merge_request id is used instead of the iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}/blocks/#{blocked_mr.id}", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request block id is not found' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks/0", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request_iid is not found' do
      get api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/blocks/#{blocked_mr.id}", user)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks/#{blocked_mr.id}" }
      end
    end
  end
end
