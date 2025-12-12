# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::Ai::ActiveContext, feature_category: :global_search do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:connection1) do
    create(:ai_active_context_connection, name: 'elastic', active: true,
      adapter_class: '::ActiveContext::Databases::Elasticsearch::Adapter')
  end

  let_it_be_with_reload(:connection2) do
    create(:ai_active_context_connection, name: 'postgres', active: false,
      adapter_class: '::ActiveContext::Databases::Postgresql::Adapter')
  end

  let_it_be(:collection) do
    create(:ai_active_context_collection, connection: connection1, name: 'gitlab_active_context_code')
  end

  let_it_be(:namespace) { create(:group) }
  let_it_be(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, namespace: namespace, active_context_connection: connection1)
  end

  shared_examples 'an API that returns 401 for unauthenticated requests' do |verb|
    it 'returns unauthorized status' do
      send(verb, api(path, nil))

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  shared_examples 'an API that returns 403 for non-admin requests' do |verb|
    it 'returns forbidden status' do
      send(verb, api(path, user))

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /admin/active_context/connections' do
    let(:path) { '/admin/active_context/connections' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :get
    it_behaves_like 'an API that returns 403 for non-admin requests', :get

    it 'returns all connections' do
      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to match_array([
        hash_including(
          'id' => connection1.id,
          'name' => 'elastic',
          'active' => true
        ),
        hash_including(
          'id' => connection2.id,
          'name' => 'postgres',
          'active' => false
        )
      ])
    end
  end

  describe 'PUT /admin/active_context/connections/activate' do
    let(:path) { '/admin/active_context/connections/activate' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put

    it 'activates the specified connection' do
      put api(path, admin, admin_mode: true), params: { connection_id: connection2.id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to include(
        'id' => connection2.id,
        'name' => 'postgres',
        'active' => true
      )

      expect(connection1.reload).not_to be_active
      expect(connection2.reload).to be_active
    end

    it 'does nothing if connection is already active' do
      put api(path, admin, admin_mode: true), params: { connection_id: connection1.id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to include(
        'id' => connection1.id,
        'active' => true
      )

      expect(connection1.reload).to be_active
    end

    it 'returns 404 for missing connection_id' do
      put api(path, admin, admin_mode: true),
        params: { connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1 }

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'PUT /admin/active_context/connections/deactivate' do
    let(:path) { '/admin/active_context/connections/deactivate' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put

    context 'when connection_id is provided' do
      it 'deactivates the specified connection' do
        put api(path, admin, admin_mode: true), params: { connection_id: connection1.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => connection1.id,
          'name' => 'elastic',
          'active' => false
        )

        expect(connection1.reload).not_to be_active
      end

      it 'does nothing if connection is already inactive' do
        put api(path, admin, admin_mode: true), params: { connection_id: connection2.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => connection2.id,
          'active' => false
        )

        expect(connection2.reload).not_to be_active
      end

      it 'returns 404 for missing connection_id' do
        put api(path, admin, admin_mode: true),
          params: { connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1 }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when connection_id is not provided' do
      it 'deactivates the currently active connection' do
        put api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => connection1.id,
          'name' => 'elastic',
          'active' => false
        )

        expect(connection1.reload).not_to be_active
      end

      context 'when no connection is active' do
        before do
          connection1.deactivate!
        end

        it 'returns 404' do
          put api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'PUT /admin/active_context/collections/:id' do
    let(:path) { "/admin/active_context/collections/#{collection.id}" }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put

    context 'when updating queue_shard_count only' do
      it 'updates the collection options' do
        put api(path, admin, admin_mode: true), params: { queue_shard_count: 32 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'name' => collection.name,
          'connection_id' => connection1.id,
          'options' => hash_including('queue_shard_count' => 32)
        )

        expect(collection.reload.queue_shard_count).to eq(32)
      end
    end

    context 'when updating queue_shard_limit only' do
      it 'updates the collection options' do
        put api(path, admin, admin_mode: true), params: { queue_shard_limit: 2000 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'name' => collection.name,
          'connection_id' => connection1.id,
          'options' => hash_including('queue_shard_limit' => 2000)
        )

        expect(collection.reload.queue_shard_limit).to eq(2000)
      end
    end

    context 'when updating both options' do
      it 'updates both queue_shard_count and queue_shard_limit' do
        put api(path, admin, admin_mode: true), params: {
          queue_shard_count: 16,
          queue_shard_limit: 500
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'name' => collection.name,
          'connection_id' => connection1.id,
          'options' => hash_including(
            'queue_shard_count' => 16,
            'queue_shard_limit' => 500
          )
        )

        collection.reload
        expect(collection.queue_shard_count).to eq(16)
        expect(collection.queue_shard_limit).to eq(500)
      end
    end

    context 'when finding collection by name' do
      let(:path) { "/admin/active_context/collections/#{collection.name}" }

      it 'updates the collection options' do
        put api(path, admin, admin_mode: true), params: { queue_shard_count: 24 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'name' => collection.name,
          'options' => hash_including('queue_shard_count' => 24)
        )

        expect(collection.reload.queue_shard_count).to eq(24)
      end
    end

    context 'with specific connection_id' do
      it 'updates collection in specified connection' do
        put api(path, admin, admin_mode: true), params: {
          queue_shard_count: 8,
          connection_id: connection1.id
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'connection_id' => connection1.id,
          'options' => hash_including('queue_shard_count' => 8)
        )

        expect(collection.reload.queue_shard_count).to eq(8)
      end

      it 'returns 404 for collection in different connection' do
        put api(path, admin, admin_mode: true), params: {
          queue_shard_count: 8,
          connection_id: connection2.id
        }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Collection Not Found')
      end
    end

    it 'returns 404 for non-existent collection ID' do
      non_existent_id = Ai::ActiveContext::Collection.maximum(:id) + 1
      put api("/admin/active_context/collections/#{non_existent_id}", admin, admin_mode: true),
        params: { queue_shard_count: 8 }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Collection Not Found')
    end

    it 'returns 404 for non-existent collection name' do
      put api('/admin/active_context/collections/non_existent_collection', admin, admin_mode: true),
        params: { queue_shard_count: 8 }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Collection Not Found')
    end

    it 'returns 404 for non-existent connection' do
      put api(path, admin, admin_mode: true), params: {
        queue_shard_count: 8,
        connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1
      }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Connection Not Found')
    end

    it 'returns 400 when no options are provided' do
      put api(path, admin, admin_mode: true), params: {}

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    context 'when preserving existing options' do
      before do
        collection.update_options!(queue_shard_count: 10, queue_shard_limit: 100)
      end

      it 'preserves existing options when updating only one' do
        put api(path, admin, admin_mode: true), params: { queue_shard_count: 20 }

        expect(response).to have_gitlab_http_status(:ok)

        collection.reload
        expect(collection.queue_shard_count).to eq(20)
        expect(collection.queue_shard_limit).to eq(100) # preserved
      end
    end
  end

  describe 'PUT /admin/active_context/code/enabled_namespaces' do
    let(:path) { '/admin/active_context/code/enabled_namespaces' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put

    context 'when finding namespace by path' do
      it 'updates enabled namespace state to ready' do
        put api(path, admin, admin_mode: true), params: { namespace_id: namespace.full_path, state: 'ready' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'ready'
        )

        expect(enabled_namespace.reload).to be_ready
      end

      it 'updates enabled namespace state to pending' do
        put api(path, admin, admin_mode: true), params: { namespace_id: namespace.full_path, state: 'pending' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'pending'
        )

        expect(enabled_namespace.reload).to be_pending
      end
    end

    context 'when finding namespace by ID' do
      it 'updates enabled namespace state' do
        put api(path, admin, admin_mode: true), params: { namespace_id: namespace.id, state: 'ready' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'ready'
        )

        expect(enabled_namespace.reload).to be_ready
      end
    end

    context 'with specific connection_id' do
      it 'updates enabled namespace in specified connection' do
        put api(path, admin, admin_mode: true), params: {
          namespace_id: namespace.full_path,
          state: 'ready',
          connection_id: connection1.id
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'ready'
        )

        expect(enabled_namespace.reload).to be_ready
      end

      it 'returns 404 for invalid connection' do
        put api(path, admin, admin_mode: true), params: {
          namespace_id: namespace.full_path,
          state: 'ready',
          connection_id: connection2.id
        }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Enabled Namespace Not Found')
      end
    end

    it 'returns 404 for non-existent namespace' do
      put api(path, admin, admin_mode: true), params: { namespace_id: 'non/existent/namespace', state: 'ready' }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Namespace Not Found')
    end

    it 'returns 404 for non-existent connection' do
      put api(path, admin, admin_mode: true), params: {
        namespace_id: namespace.full_path,
        state: 'ready',
        connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1
      }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Connection Not Found')
    end

    it 'returns 400 for invalid state' do
      put api(path, admin, admin_mode: true), params: { namespace_id: namespace.full_path, state: 'invalid_state' }

      expect(response).to have_gitlab_http_status(:bad_request)
    end
  end
end
