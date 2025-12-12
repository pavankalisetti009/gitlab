# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::KnowledgeGraph, feature_category: :knowledge_graph do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:namespace) { create(:group) }

  shared_examples 'an API that returns 400 when the feature flag is disabled' do |verb|
    before do
      stub_feature_flags(knowledge_graph: false)
    end

    it 'returns bad_request status' do
      send(verb, api(path, admin, admin_mode: true))

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to eq('knowledge_graph feature flag is not enabled')
    end
  end

  shared_examples 'an API that returns 401 for unauthenticated requests' do |verb|
    it 'returns unauthorized status' do
      send(verb, api(path, nil))

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  shared_examples 'an API that returns 403 for non-admin users' do |verb|
    let_it_be(:user) { create(:user) }

    it 'returns forbidden status' do
      send(verb, api(path, user))

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /admin/knowledge_graph/namespaces' do
    let(:path) { '/admin/knowledge_graph/namespaces' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :get
    it_behaves_like 'an API that returns 403 for non-admin users', :get
    it_behaves_like 'an API that returns 400 when the feature flag is disabled', :get

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(knowledge_graph: true)
      end

      it 'returns enabled namespaces' do
        enabled_namespace = create(:knowledge_graph_enabled_namespace, namespace: namespace)

        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to contain_exactly(
          hash_including(
            'id' => enabled_namespace.id,
            'root_namespace_id' => namespace.id
          )
        )
      end

      it 'returns at most MAX_RESULTS most recent rows' do
        stub_const("#{described_class}::MAX_RESULTS", 1)

        create(:knowledge_graph_enabled_namespace)
        enabled_namespace_2 = create(:knowledge_graph_enabled_namespace)

        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to contain_exactly(
          hash_including('id' => enabled_namespace_2.id)
        )
      end
    end
  end

  describe 'PUT /admin/knowledge_graph/namespaces/:id' do
    let(:namespace_id) { namespace.id }
    let(:path) { "/admin/knowledge_graph/namespaces/#{namespace_id}" }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin users', :put
    it_behaves_like 'an API that returns 400 when the feature flag is disabled', :put

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(knowledge_graph: true)
      end

      it 'creates a KnowledgeGraph::EnabledNamespace for the namespace' do
        expect do
          put api(path, admin, admin_mode: true)
        end.to change { ::Ai::KnowledgeGraph::EnabledNamespace.count }.from(0).to(1)

        expect(response).to have_gitlab_http_status(:ok)
        enabled_namespace = ::Ai::KnowledgeGraph::EnabledNamespace.find_by(root_namespace_id: namespace.id)
        expect(json_response['id']).to eq(enabled_namespace.id)
        expect(json_response['root_namespace_id']).to eq(namespace.id)
      end

      context 'when using namespace path' do
        let(:namespace_id) { namespace.full_path }

        it 'creates a KnowledgeGraph::EnabledNamespace for the namespace' do
          expect do
            put api(path, admin, admin_mode: true)
          end.to change { ::Ai::KnowledgeGraph::EnabledNamespace.count }.from(0).to(1)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when using a subgroup' do
        let_it_be(:subgroup) { create(:group, parent: namespace) }
        let(:namespace_id) { subgroup.id }

        it 'returns bad_request status' do
          put api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('Namespace must be a root namespace')
        end
      end

      context 'when it already exists' do
        it 'returns the existing one' do
          enabled_namespace = create(:knowledge_graph_enabled_namespace, namespace: namespace)

          put api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(enabled_namespace.id)
        end
      end

      context 'when namespace does not exist' do
        let(:namespace_id) { non_existing_record_id }

        it 'returns not_found status' do
          put api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'DELETE /admin/knowledge_graph/namespaces/:id' do
    let(:namespace_id) { namespace.id }
    let(:path) { "/admin/knowledge_graph/namespaces/#{namespace_id}" }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :delete
    it_behaves_like 'an API that returns 403 for non-admin users', :delete
    it_behaves_like 'an API that returns 400 when the feature flag is disabled', :delete

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(knowledge_graph: true)
      end

      context 'when enabled namespace exists' do
        let!(:enabled_namespace) { create(:knowledge_graph_enabled_namespace, namespace: namespace) }

        it 'removes the KnowledgeGraph::EnabledNamespace' do
          expect do
            delete api(path, admin, admin_mode: true)
          end.to change { ::Ai::KnowledgeGraph::EnabledNamespace.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end

        context 'when using namespace path' do
          let(:namespace_id) { namespace.full_path }

          it 'removes the KnowledgeGraph::EnabledNamespace' do
            expect do
              delete api(path, admin, admin_mode: true)
            end.to change { ::Ai::KnowledgeGraph::EnabledNamespace.count }.by(-1)

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end

        context 'when using a subgroup' do
          let_it_be(:subgroup) { create(:group, parent: namespace) }
          let(:namespace_id) { subgroup.id }

          it 'returns bad_request status' do
            delete api(path, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('Namespace must be a root namespace')
          end
        end
      end

      context 'when enabled namespace does not exist' do
        it 'returns not_found status' do
          delete api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when namespace does not exist' do
        let(:namespace_id) { non_existing_record_id }

        it 'returns not_found status' do
          delete api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
