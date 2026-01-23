# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupRepositoryStorageMoves, feature_category: :gitaly do
  let_it_be(:user) { create(:admin) }
  let_it_be(:container) { create(:group, :wiki_repo) }
  let_it_be(:storage_move) { create(:group_repository_storage_move, :scheduled, container: container) }

  it_behaves_like 'repository_storage_moves API', 'groups' do
    let(:repository_storage_move_factory) { :group_repository_storage_move }
    let(:bulk_worker_klass) { Groups::ScheduleBulkRepositoryShardMovesWorker }
  end

  describe "GET /groups/:id/repository_storage_moves" do
    it_behaves_like 'authorizing granular token permissions', :read_repository_storage_move do
      let(:boundary_object) { container }
      let(:request) do
        get api("/groups/#{container.id}/repository_storage_moves",
          personal_access_token: pat)
      end
    end
  end

  describe "GET /groups/:id/repository_storage_moves/:repository_storage_move_id" do
    it_behaves_like 'authorizing granular token permissions', :read_repository_storage_move do
      let(:boundary_object) { container }
      let(:request) do
        get api("/groups/#{container.id}/repository_storage_moves/#{storage_move.id}",
          personal_access_token: pat)
      end
    end
  end

  describe "POST /groups/:id/repository_storage_moves" do
    before do
      stub_storage_settings('test_second_storage' => {})
    end

    it_behaves_like 'authorizing granular token permissions', :create_repository_storage_move do
      let(:boundary_object) { container }
      let(:request) do
        post api("/groups/#{container.id}/repository_storage_moves", personal_access_token: pat),
          params: { destination_storage_name: 'test_second_storage' }
      end
    end
  end
end
