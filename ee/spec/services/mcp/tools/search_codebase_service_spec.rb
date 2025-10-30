# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::SearchCodebaseService, feature_category: :mcp_server do
  let(:service_name) { 'get_code_context' }
  let(:current_user) { create(:user) }
  let(:project) { create :project, :repository }
  let_it_be(:oauth_token) { 'test_token_123' }

  let(:service) { described_class.new(name: service_name, version: '0.1.0') }

  describe 'version registration' do
    it 'registers version 0.1.0' do
      expect(described_class.version_exists?('0.1.0')).to be true
    end

    it 'has 0.1.0 as the latest version' do
      expect(described_class.latest_version).to eq('0.1.0')
    end

    it 'returns available versions in order' do
      expect(described_class.available_versions).to eq(['0.1.0'])
    end
  end

  describe 'version metadata' do
    describe 'version 0.1.0' do
      let(:metadata) { described_class.version_metadata('0.1.0') }

      it 'has correct description' do
        expect(metadata[:description]).to eq <<~DESC.strip
          Performs semantic code search across project files using vector similarity.

          Returns ranked code snippets with file paths and content matches based on natural language queries.

          Use this tool for questions about a project's codebase.
          For example: "how something works" or "code that does X", or finding specific implementations.

          This tool supports directory scoping and configurable result limits for targeted code discovery and analysis.
        DESC
      end

      it 'has correct input schema' do
        expect(metadata[:input_schema]).to eq({
          type: 'object',
          properties: {
            semantic_query: {
              type: 'string',
              minLength: 1,
              maxLength: 1000,
              description: "A brief natural language query about the code you want to find in the project " \
                "(e.g.: 'authentication middleware', 'database connection logic', or 'API error handling')."
            },
            project_id: {
              type: 'string',
              description: 'Either a project id or project path.'
            },
            directory_path: {
              type: 'string',
              minLength: 1,
              maxLength: 100,
              description: 'Optional directory path to scope the search (e.g., "app/services/").'
            },
            knn: {
              type: 'integer',
              default: 64,
              minimum: 1,
              maximum: 100,
              description: 'Number of nearest neighbors used internally. ' \
                "This controls search precision vs. speed - higher values find more diverse results but take longer."
            },
            limit: {
              type: 'integer',
              default: 20,
              minimum: 1,
              maximum: 100,
              description: 'Maximum number of results to return.'
            }
          },
          required: %w[semantic_query project_id],
          additionalProperties: false
        })
      end
    end
  end

  describe 'initialization' do
    context 'when no version is specified' do
      it 'uses the latest version' do
        service = described_class.new(name: service_name)
        expect(service.version).to eq('0.1.0')
      end
    end

    context 'when version 0.1.0 is specified' do
      it 'uses version 0.1.0' do
        service = described_class.new(name: service_name, version: '0.1.0')
        expect(service.version).to eq('0.1.0')
      end
    end

    context 'when invalid version is specified' do
      it 'raises ArgumentError' do
        expect { described_class.new(name: service_name, version: '1.0.0') }
          .to raise_error(ArgumentError, 'Version 1.0.0 not found. Available: 0.1.0')
      end
    end
  end

  describe '#description' do
    it 'returns the correct description' do
      service = described_class.new(name: service_name, version: '0.1.0')
      expect(service.description).to eq <<~DESC.strip
        Performs semantic code search across project files using vector similarity.

        Returns ranked code snippets with file paths and content matches based on natural language queries.

        Use this tool for questions about a project's codebase.
        For example: "how something works" or "code that does X", or finding specific implementations.

        This tool supports directory scoping and configurable result limits for targeted code discovery and analysis.
      DESC
    end
  end

  describe '#input_schema' do
    it 'returns the expected JSON schema' do
      service = described_class.new(name: service_name, version: '0.1.0')
      expect(service.input_schema).to eq({
        type: 'object',
        properties: {
          semantic_query: {
            type: 'string',
            minLength: 1,
            maxLength: 1000,
            description: "A brief natural language query about the code you want to find in the project " \
              "(e.g.: 'authentication middleware', 'database connection logic', or 'API error handling')."
          },
          project_id: {
            type: 'string',
            description: 'Either a project id or project path.'
          },
          directory_path: {
            type: 'string',
            minLength: 1,
            maxLength: 100,
            description: 'Optional directory path to scope the search (e.g., "app/services/").'
          },
          knn: {
            type: 'integer',
            default: 64,
            minimum: 1,
            maximum: 100,
            description: 'Number of nearest neighbors used internally. ' \
              "This controls search precision vs. speed - higher values find more diverse results but take longer."
          },
          limit: {
            type: 'integer',
            default: 20,
            minimum: 1,
            maximum: 100,
            description: 'Maximum number of results to return.'
          }
        },
        required: %w[semantic_query project_id],
        additionalProperties: false
      })
    end
  end

  describe '#execute' do
    before do
      service.set_cred(current_user: current_user, access_token: oauth_token)
    end

    context 'with valid arguments' do
      let(:arguments) do
        {
          arguments: {
            semantic_query: 'Add raise Exception for protected type usage',
            project_id: project_id,
            directory_path: 'app/services/'
          }
        }
      end

      let(:query_obj) { instance_double(::Ai::ActiveContext::Queries::Code) }

      let(:raw_hits) do
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

      let(:query_result) do
        ::Ai::ActiveContext::Queries::Result.success(raw_hits)
      end

      before do
        allow(::Ai::ActiveContext::Queries::Code)
          .to receive(:new)
          .and_return(query_obj)
        project.add_developer(current_user)
      end

      shared_examples 'tool executed with expected response' do
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
            .and_return(query_result)

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

        context 'when the given project has no code embeddings' do
          let(:query_result) do
            ::Ai::ActiveContext::Queries::Result.no_embeddings_error
          end

          it 'returns an error response' do
            allow(::Ai::ActiveContext::Queries::Code)
              .to receive(:new)
              .with(search_term: 'Add raise Exception for protected type usage', user: current_user)
              .and_return(query_obj)

            allow(query_obj)
              .to receive(:filter)
              .and_return(query_result)

            response = service.execute(request: nil, params: arguments)

            expect(response[:isError]).to be true

            expected_error_detail = "Project '#{project_id}' has no embeddings"
            expected_error_message = "Unable to perform semantic search, #{expected_error_detail}"
            expect(response[:content].first[:text]).to eq("Tool execution failed: #{expected_error_message}.")
            expect(response[:structuredContent][:error]).to eq(expected_error_detail)
          end
        end
      end

      context 'with project ID' do
        let(:project_id) { project.id.to_s }

        it_behaves_like 'tool executed with expected response'
      end

      context 'with project full path' do
        let(:project_id) { project.full_path }

        it_behaves_like 'tool executed with expected response'
      end
    end

    context 'with missing required field' do
      before do
        project.add_developer(current_user)
      end

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
        expect(result[:content].first[:text]).to eq("Tool execution failed: get_code_context: project not " \
          "found, the params received: {:arguments=>{:semantic_query=>\"foo\"}}")
      end
    end

    context 'with blank/invalid required field' do
      before do
        project.add_developer(current_user)
      end

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

      it 'returns Tool execution failed validation error when project_id is not an string' do
        arguments = { arguments: { semantic_query: 'foo', project_id: 1 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Tool execution failed: Validation error: " \
          "project_id must be a string")
      end

      it 'returns validation error when limit is too big' do
        arguments = { arguments: { semantic_query: 'foo', project_id: project.id.to_s, limit: 101 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: limit is invalid")
      end

      it 'returns validation error when project id not found' do
        arguments = { arguments: { semantic_query: 'foo', project_id: '-1' } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Tool execution failed: Project '-1' not found or inaccessible")
      end

      it 'returns validation error when knn is too small' do
        arguments = { arguments: { semantic_query: 'foo', project_id: project.id.to_s, knn: 0 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: knn is invalid")
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

    context 'when authorization failed' do
      let(:arguments) do
        {
          arguments: {
            semantic_query: 'Add raise Exception for protected type usage',
            project_id: project.id.to_s,
            directory_path: 'app/services/'
          }
        }
      end

      it 'returns authorization error' do
        response = service.execute(request: nil, params: arguments)

        expect(response[:isError]).to be true
        expect(response[:content]).to be_an(Array)
        expect(response[:content].first[:type]).to eq('text')
        expect(response[:content].first[:text]).to eq(
          "Tool execution failed: CustomService: User #{current_user.id} does " \
            "not have permission to read_code for target #{project.id}"
        )
      end
    end
  end

  describe '#available?' do
    subject(:available?) { service.available? }

    context 'when Code collection is indexed' do
      it { is_expected.to be(false) }
    end

    context 'when code collection is indexed' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)

        create(
          :ai_active_context_collection,
          name: Ai::ActiveContext::Collections::Code.collection_name,
          search_embedding_version: 1,
          include_ref_fields: false
        )
      end

      context 'when current_user is not set' do
        it { is_expected.to be(false) }
      end

      context 'when current_user is set' do
        before do
          service.set_cred(current_user: current_user)
        end

        it { is_expected.to be(true) }

        context 'when `code_snippet_search_graphqlapi` is disabled' do
          before do
            stub_feature_flags(code_snippet_search_graphqlapi: false)
          end

          it { is_expected.to be(false) }
        end
      end
    end
  end
end
