# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying semantic code search via GraphQL', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { project.owner }

  let(:result) do
    [
      { path: 'python/server.py', content: 'from http.server import HTTPServer' }
    ]
  end

  let(:fields) do
    <<~GRAPHQL
      path
      content
    GRAPHQL
  end

  let(:variables) do
    {
      limit: limit,
      knn: knn_count,
      project: project_info,
      searchTerm: search_term
    }
  end

  let(:query) { graphql_query_for('semanticCodeSearch', variables, fields) }

  before do
    stub_feature_flags(code_snippet_search_graphqlapi: true)
  end

  context 'with project id and directory path' do
    let(:project_info) { { projectId: project.id, directoryPath: 'python/server.py' } }
    let(:search_term)  { 'Add raise Exception for protected type usage' }
    let(:knn_count)    { 64 }
    let(:limit)        { 20 }

    it 'returns code snippets' do
      allow_next_instance_of(Ai::ActiveContext::Queries::Code) do |inst|
        expect(inst).to receive(:filter).with(
          project_id: project.id,
          path: 'python/server.py',
          knn_count: 64,
          limit: 20
        ).and_return(result)
      end

      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data['semanticCodeSearch']).to contain_exactly(
        a_hash_including('path' => 'python/server.py', 'content' => 'from http.server import HTTPServer')
      )
    end
  end

  context 'when feature flag is disabled' do
    let(:project_info) { { projectId: project.id } }
    let(:search_term)  { 'anything' }
    let(:knn_count)    { 64 }
    let(:limit)        { 20 }

    before do
      stub_feature_flags(code_snippet_search_graphqlapi: false)
    end

    it 'returns a GraphQL error' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message']).to eq('`code_snippet_search_graphqlapi` feature flag is disabled.')
    end
  end

  context 'with invalid knn' do
    let(:project_info) { { projectId: project.id } }
    let(:search_term)  { 'query' }
    let(:knn_count)    { 0 }
    let(:limit)        { 20 }

    it 'returns a validation error' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message']).to eq('knn must be greater than 0')
    end
  end

  context 'with no limit' do
    let(:project_info) { { projectId: project.id } }
    let(:search_term)  { 'query' }
    let(:knn_count)    { 64 }
    let(:variables) do
      {
        knn: knn_count,
        project: project_info,
        searchTerm: search_term
      }
    end

    it 'uses default limit' do
      allow_next_instance_of(Ai::ActiveContext::Queries::Code) do |inst|
        expect(inst).to receive(:filter).with(
          project_id: project.id,
          path: nil,
          knn_count: 64,
          limit: 10
        ).and_return(result)
      end

      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(graphql_data['semanticCodeSearch']).to contain_exactly(
        a_hash_including('path' => 'python/server.py', 'content' => 'from http.server import HTTPServer')
      )
    end
  end
end
