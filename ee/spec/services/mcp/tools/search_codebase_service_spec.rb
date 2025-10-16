# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::SearchCodebaseService, feature_category: :mcp_server do
  let(:service) { described_class.new(name: 'get_code_context') }

  describe '#description' do
    it 'returns the correct description' do
      expected_description = <<~DESC
        Performs semantic code search across project files using vector similarity.

        Returns ranked code snippets with file paths and content matches based on natural language queries.

        Use this tool for questions about a project's codebase.
        For example: "how something works" or "code that does X", or finding specific implementations.

        This tool supports directory scoping and configurable result limits for targeted code discovery and analysis.
      DESC

      expect(service.description).to eq(expected_description.strip)
    end
  end

  describe '#input_schema' do
    it 'returns the expected JSON schema' do
      schema = service.input_schema

      expect(schema[:type]).to eq('object')
      expect(schema[:required]).to match_array(%w[semantic_query project_id])
      expect(schema[:additionalProperties]).to be false

      expect(schema[:properties][:semantic_query][:type]).to eq('string')
      expect(schema[:properties][:semantic_query][:minLength]).to eq(1)

      expect(schema[:properties][:project_id][:type]).to eq('string')

      expect(schema[:properties][:directory_path][:type]).to eq('string')

      expect(schema[:properties][:knn][:type]).to eq('integer')
      expect(schema[:properties][:knn][:default]).to eq(64)
      expect(schema[:properties][:knn][:minimum]).to eq(1)

      expect(schema[:properties][:limit][:type]).to eq('integer')
      expect(schema[:properties][:limit][:default]).to eq(20)
      expect(schema[:properties][:limit][:minimum]).to eq(1)
    end
  end

  describe '#execute' do
    let_it_be(:oauth_token) { 'test_token_123' }
    let_it_be(:current_user) { build(:user) }
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, :public, namespace: namespace) }

    before do
      service.set_cred(current_user: current_user, access_token: oauth_token)
    end

    context 'with valid arguments' do
      let(:query_obj) { instance_double(::Ai::ActiveContext::Queries::Code) }

      let(:raw_hit) do
        [
          {
            'project_id' => 1000000,
            'path' => 'ruby/server.rb',
            'content' => "require 'webrick'",
            'name' => 'server.rb',
            'blob_id' => '3a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d',
            'start_line' => 0,
            'start_byte' => 0,
            'language' => 'ruby'
          }
        ]
      end

      before do
        allow(::Ai::ActiveContext::Queries::Code)
          .to receive(:new)
          .and_return(query_obj)
      end

      context 'with project ID' do
        let(:arguments) do
          {
            arguments: {
              semantic_query: 'Add raise Exception for protected type usage',
              project_id: project.id.to_s,
              directory_path: 'app/services/'
            }
          }
        end

        it 'initializes the code query with search term and current_user and filters with expected params' do
          expect(::Ai::ActiveContext::Queries::Code)
            .to receive(:new)
            .with(search_term: 'Add raise Exception for protected type usage', user: current_user)
            .and_return(query_obj)

          expect(query_obj)
            .to receive(:filter)
            .with(
              project_id: project.id,
              path: 'app/services/',
              knn_count: 64,
              limit: 20,
              exclude_fields: %w[id source type embeddings_v1 reindexing],
              extract_source_segments: true)
            .and_return(raw_hit)

          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          expect(response[:content]).to be_an(Array)
          expect(response[:content].first[:type]).to eq('text')

          expect(response[:content].first[:text]).to eq("1. ruby/server.rb\n   require 'webrick'")

          structured = response[:structuredContent]
          expect(structured).to be_a(Hash)
          expect(structured[:metadata]).to eq({ count: 1, has_more: false })
          item = structured[:items].first
          expect(item).to eq(
            {
              'project_id' => 1_000_000,
              'path' => 'ruby/server.rb',
              'content' => "require 'webrick'",
              'name' => 'server.rb',
              'language' => 'ruby',
              'blob_id' => '3a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d',
              'start_line' => 0,
              'start_byte' => 0
            }
          )
        end
      end

      context 'with project full path' do
        let(:arguments) do
          {
            arguments: {
              semantic_query: 'Add raise Exception for protected type usage',
              project_id: project.full_path,
              directory_path: 'app/services/'
            }
          }
        end

        it 'initializes the code query with search term and current_user and filters with expected params' do
          expect(::Ai::ActiveContext::Queries::Code)
            .to receive(:new)
            .with(search_term: 'Add raise Exception for protected type usage', user: current_user)
            .and_return(query_obj)

          expect(query_obj)
            .to receive(:filter)
            .with(
              project_id: project.id,
              path: 'app/services/',
              knn_count: 64,
              limit: 20,
              exclude_fields: %w[id source type embeddings_v1 reindexing],
              extract_source_segments: true)
            .and_return(raw_hit)

          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          expect(response[:content]).to be_an(Array)
          expect(response[:content].first[:type]).to eq('text')

          expect(response[:content].first[:text]).to eq("1. ruby/server.rb\n   require 'webrick'")

          structured = response[:structuredContent]
          expect(structured).to be_a(Hash)
          expect(structured[:metadata]).to eq({ count: 1, has_more: false })
          item = structured[:items].first
          expect(item).to eq(
            {
              'project_id' => 1_000_000,
              'path' => 'ruby/server.rb',
              'content' => "require 'webrick'",
              'name' => 'server.rb',
              'language' => 'ruby',
              'blob_id' => '3a99909a7fa51ffd3fe6f9de3ab47dfbf2f59a9d',
              'start_line' => 0,
              'start_byte' => 0
            }
          )
        end
      end
    end

    context 'with missing required field' do
      it 'returns validation error when semantic_query is missing' do
        arguments = { arguments: { project_id: project.id.to_s } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: semantic_query is missing")
      end

      it 'returns validation error when project_id is missing' do
        arguments = { arguments: { semantic_query: 'foo' } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: project_id is missing")
      end
    end

    context 'with blank/invalid required field' do
      it 'returns validation error when semantic_query is blank' do
        arguments = { arguments: { semantic_query: '', project_id: project.id.to_s } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: semantic_query is invalid")
      end

      it 'returns validation error when semantic_query is too long' do
        arguments = { arguments: { semantic_query: 'a' * 1001, project_id: project.id.to_s } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: semantic_query is invalid")
      end

      it 'returns validation error when directory_path is too long' do
        arguments = { arguments: { semantic_query: 'foo', project_id: project.id.to_s, directory_path: 'a' * 101 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: directory_path is invalid")
      end

      it 'returns validation error when project_id is not an string' do
        arguments = { arguments: { semantic_query: 'foo', project_id: 1 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: project_id is invalid")
      end

      it 'returns validation error when limit is too big' do
        arguments = { arguments: { semantic_query: 'foo', project_id: project.id.to_s, limit: 101 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: limit is invalid")
      end

      it 'returns validation error when knn is too small' do
        arguments = { arguments: { semantic_query: 'foo', project_id: project.id.to_s, knn: 0 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: knn is invalid")
      end

      it 'returns validation error when project id not found' do
        arguments = { arguments: { semantic_query: 'foo', project_id: '-1' } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Tool execution failed: Project '-1' not found or inaccessible")
      end

      it 'returns validation error when project path not found' do
        arguments = { arguments: { semantic_query: 'foo', project_id: '/not/a/valid/path' } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq(
          "Tool execution failed: Project '/not/a/valid/path' not found or inaccessible"
        )
      end
    end
  end
end
