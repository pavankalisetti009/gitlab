# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::SemanticCodeSearchService, feature_category: :mcp_server do
  let(:service_name) { 'semantic_code_search' }
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
          Code search using natural language.

          Returns ranked code snippets with file paths and matching content for natural-language queries.

          Primary use cases:
          - When you do not know the exact symbol or file path
          - To see how a behavior or feature is implemented across the codebase
          - To discover related implementations (clients, jobs, feature flags, background workers)

          How to use:
          - Provide a concise, specific query (1–2 sentences) with concrete keywords like endpoint, class, or framework names
          - Add directory_path to narrow scope, e.g., "app/services/" or "ee/app/workers/"
          - Prefer precise intent over broad terms (e.g., "rate limiting middleware for REST API" instead of "rate limit")

          Example queries:
          - semantic_query: "JWT verification middleware" with directory_path: "app/"
          - semantic_query: "CI pipeline triggers downstream jobs" with directory_path: "lib/"
          - semantic_query: "feature flag to disable email notifications" (no directory_path)

          Output:
          - Ranked snippets with file paths and the matched content for each hit
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
    let(:service) { described_class.new(name: service_name, version: '0.1.0') }

    let(:base_description) do
      <<~DESC.strip
        Code search using natural language.

        Returns ranked code snippets with file paths and matching content for natural-language queries.

        Primary use cases:
        - When you do not know the exact symbol or file path
        - To see how a behavior or feature is implemented across the codebase
        - To discover related implementations (clients, jobs, feature flags, background workers)

        How to use:
        - Provide a concise, specific query (1–2 sentences) with concrete keywords like endpoint, class, or framework names
        - Add directory_path to narrow scope, e.g., "app/services/" or "ee/app/workers/"
        - Prefer precise intent over broad terms (e.g., "rate limiting middleware for REST API" instead of "rate limit")

        Example queries:
        - semantic_query: "JWT verification middleware" with directory_path: "app/"
        - semantic_query: "CI pipeline triggers downstream jobs" with directory_path: "lib/"
        - semantic_query: "feature flag to disable email notifications" (no directory_path)

        Output:
        - Ranked snippets with file paths and the matched content for each hit
      DESC
    end

    before do
      service.set_cred(current_user: current_user)
    end

    context 'when post_process_semantic_code_search_add_score feature flag is enabled' do
      before do
        stub_feature_flags(
          post_process_semantic_code_search_add_score: true,
          post_process_semantic_code_search_overall_confidence: false,
          post_process_semantic_code_search_group_by_file: false
        )
      end

      it 'returns description with score information' do
        expect(service.description).to eq("#{base_description}\n#{described_class::SCORE_DESCRIPTION}")
      end
    end

    context 'when post_process_semantic_code_search_add_score feature flag is disabled' do
      before do
        stub_feature_flags(
          post_process_semantic_code_search_add_score: false,
          post_process_semantic_code_search_overall_confidence: false,
          post_process_semantic_code_search_group_by_file: false
        )
      end

      it 'returns base description without score information' do
        expect(service.description).to eq(base_description)
      end
    end

    context 'when post_process_semantic_code_search_overall_confidence feature flag is enabled' do
      before do
        stub_feature_flags(
          post_process_semantic_code_search_add_score: false,
          post_process_semantic_code_search_overall_confidence: true,
          post_process_semantic_code_search_group_by_file: false
        )
      end

      it 'returns description with confidence information' do
        expect(service.description).to eq("#{base_description}\n#{described_class::CONFIDENCE_DESCRIPTION}")
      end
    end

    context 'when both score and confidence feature flags are enabled' do
      before do
        stub_feature_flags(
          post_process_semantic_code_search_add_score: true,
          post_process_semantic_code_search_overall_confidence: true,
          post_process_semantic_code_search_group_by_file: false
        )
      end

      it 'returns description with both score and confidence information' do
        expected = [base_description, described_class::SCORE_DESCRIPTION,
          described_class::CONFIDENCE_DESCRIPTION].join("\n")
        expect(service.description).to eq(expected)
      end
    end

    context 'when post_process_semantic_code_search_group_by_file feature flag is enabled' do
      before do
        stub_feature_flags(
          post_process_semantic_code_search_add_score: false,
          post_process_semantic_code_search_overall_confidence: false,
          post_process_semantic_code_search_group_by_file: true
        )
      end

      it 'returns description with grouping information' do
        expect(service.description).to eq("#{base_description}\n#{described_class::GROUPING_DESCRIPTION}")
      end
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
            'language' => 'ruby',
            'file_url' => 'http://project/-/blob/master/ruby/server.rb',
            'score' => 0.9523
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
        stub_feature_flags(
          post_process_semantic_code_search_add_score: true,
          post_process_semantic_code_search_overall_confidence: false,
          post_process_semantic_code_search_group_by_file: false
        )
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
              project_or_id: project,
              path: 'app/services/',
              knn_count: 64,
              limit: 20,
              exclude_fields: %w[id source type embeddings_v1 reindexing],
              extract_source_segments: true,
              build_file_url: true)
            .and_return(query_result)

          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          expect(response[:content]).to be_an(Array)
          expect(response[:content].first[:type]).to eq('text')

          expect(response[:content].first[:text]).to eq("1. ruby/server.rb (score: 0.9523)\nrequire 'webrick'")

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
              'start_byte' => 0,
              'file_url' => 'http://project/-/blob/master/ruby/server.rb',
              'score' => 0.9523
            }
          )
        end

        context 'when the given project has no code embeddings' do
          let(:query_result) do
            ::Ai::ActiveContext::Queries::Result.no_embeddings_error(
              error_detail: "initial indexing has been started"
            )
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

            expected_error_detail = "Project '#{project_id}' has no embeddings - initial indexing has been started"
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

      context 'when exclusion rules filter some results' do
        let(:project_id) { project.id.to_s }
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
            },
            {
              'project_id' => 1000000,
              'path' => 'docs/README.md',
              'content' => '# Documentation',
              'name' => 'README.md',
              'blob_id' => '4b00010b8fa51ffd3fe6f9de3ab47dfbf2f59b8e',
              'start_line' => 0,
              'start_byte' => 0,
              'language' => 'markdown'
            }
          ]
        end

        before do
          project.create_project_setting unless project.project_setting
          project.project_setting.update!(
            duo_context_exclusion_settings: { exclusion_rules: ['*.md'] }
          )

          allow(query_obj).to receive(:filter).and_return(query_result)
        end

        it 'excludes filtered files from structured data' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false

          # Verify filtered content only shows non-excluded file
          expect(response[:content].first[:text]).to eq("1. ruby/server.rb\nrequire 'webrick'")

          # Verify structured data only contains non-excluded file
          structured = response[:structuredContent]
          expect(structured[:metadata][:count]).to eq(1)
          expect(structured[:items].size).to eq(1)
          expect(structured[:items].first['path']).to eq('ruby/server.rb')

          # Ensure the excluded file is NOT in structured data
          paths = structured[:items].pluck('path')
          expect(paths).not_to include('docs/README.md')
        end
      end

      context 'when post_process_semantic_code_search_add_score feature flag is disabled' do
        let(:project_id) { project.id.to_s }
        let(:raw_hits_without_score) do
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

        let(:query_result_without_score) do
          ::Ai::ActiveContext::Queries::Result.success(raw_hits_without_score)
        end

        before do
          stub_feature_flags(
            post_process_semantic_code_search_add_score: false,
            post_process_semantic_code_search_overall_confidence: false
          )
          allow(query_obj).to receive(:filter).and_return(query_result_without_score)
        end

        it 'excludes score from text output and structured data' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false

          # Text output should NOT include score
          expect(response[:content].first[:text]).to eq("1. ruby/server.rb\nrequire 'webrick'")

          # Structured data should NOT include score
          structured = response[:structuredContent]
          item = structured[:items].first
          expect(item).not_to have_key('score')
          expect(item['path']).to eq('ruby/server.rb')
        end
      end

      context 'when post_process_semantic_code_search_overall_confidence feature flag is enabled' do
        let(:project_id) { project.id.to_s }

        before do
          stub_feature_flags(
            post_process_semantic_code_search_add_score: false,
            post_process_semantic_code_search_overall_confidence: true
          )
          allow(query_obj).to receive(:filter).and_return(query_result)
        end

        it 'includes confidence level in text output' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          # With single high score (0.9523), should be HIGH confidence
          expect(response[:content].first[:text]).to start_with("Confidence: HIGH\n\n")
        end

        it 'includes confidence level in structured data metadata' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          structured = response[:structuredContent]
          expect(structured[:metadata][:confidence]).to eq(:high)
          expect(structured[:metadata][:count]).to eq(1)
          expect(structured[:items]).to be_an(Array)
        end

        context 'with multiple results showing steep drop-off' do
          let(:raw_hits) do
            [
              { 'path' => 'file1.rb', 'content' => 'code1', 'score' => 0.85 },
              { 'path' => 'file2.rb', 'content' => 'code2', 'score' => 0.65 }
            ]
          end

          it 'returns HIGH confidence' do
            response = service.execute(request: nil, params: arguments)
            expect(response[:content].first[:text]).to start_with("Confidence: HIGH\n\n")
          end
        end

        context 'with multiple results showing gradual decline' do
          let(:raw_hits) do
            [
              { 'path' => 'file1.rb', 'content' => 'code1', 'score' => 0.75 },
              { 'path' => 'file2.rb', 'content' => 'code2', 'score' => 0.70 }
            ]
          end

          it 'returns MEDIUM confidence' do
            response = service.execute(request: nil, params: arguments)
            expect(response[:content].first[:text]).to start_with("Confidence: MEDIUM\n\n")
          end
        end

        context 'with low scoring results' do
          let(:raw_hits) do
            [
              { 'path' => 'file1.rb', 'content' => 'code1', 'score' => 0.40 },
              { 'path' => 'file2.rb', 'content' => 'code2', 'score' => 0.35 }
            ]
          end

          it 'returns LOW confidence' do
            response = service.execute(request: nil, params: arguments)
            expect(response[:content].first[:text]).to start_with("Confidence: LOW\n\n")
          end
        end

        context 'with no results' do
          let(:raw_hits) { [] }

          it 'returns UNKNOWN confidence' do
            response = service.execute(request: nil, params: arguments)
            expect(response[:content].first[:text]).to eq("Confidence: UNKNOWN\n\n")
          end
        end

        context 'with results but no scores (e.g., PostgreSQL backend)' do
          let(:raw_hits) do
            [
              { 'path' => 'file1.rb', 'content' => 'code1' },
              { 'path' => 'file2.rb', 'content' => 'code2' }
            ]
          end

          it 'returns UNKNOWN confidence' do
            response = service.execute(request: nil, params: arguments)
            expect(response[:content].first[:text]).to start_with("Confidence: UNKNOWN\n\n")
          end

          it 'includes unknown confidence in structured data metadata' do
            response = service.execute(request: nil, params: arguments)
            structured = response[:structuredContent]
            expect(structured[:metadata][:confidence]).to eq(:unknown)
          end
        end
      end

      context 'when post_process_semantic_code_search_overall_confidence feature flag is disabled' do
        let(:project_id) { project.id.to_s }

        before do
          stub_feature_flags(
            post_process_semantic_code_search_add_score: true,
            post_process_semantic_code_search_overall_confidence: false
          )
          allow(query_obj).to receive(:filter).and_return(query_result)
        end

        it 'does not include confidence level in text output' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          expect(response[:content].first[:text]).not_to include("Confidence:")
        end

        it 'does not include confidence in structured data metadata' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          structured = response[:structuredContent]
          # When confidence is disabled, structured data uses default format (items array wrapped by Response)
          expect(structured[:metadata]).not_to have_key(:confidence)
        end
      end

      context 'when post_process_semantic_code_search_group_by_file feature flag is enabled' do
        let(:project_id) { project.id.to_s }
        let(:grouping_hits) do
          [
            {
              'project_id' => 1000000,
              'path' => 'app/services/user_service.rb',
              'content' => 'def create_user',
              'name' => 'user_service.rb',
              'blob_id' => 'abc123',
              'start_line' => 10,
              'start_byte' => 0,
              'language' => 'ruby',
              'score' => 0.9
            },
            {
              'project_id' => 1000000,
              'path' => 'app/services/user_service.rb',
              'content' => 'def update_user',
              'name' => 'user_service.rb',
              'blob_id' => 'abc123',
              'start_line' => 11,
              'start_byte' => 100,
              'language' => 'ruby',
              'score' => 0.8
            },
            {
              'project_id' => 1000000,
              'path' => 'app/models/user.rb',
              'content' => 'class User',
              'name' => 'user.rb',
              'blob_id' => 'def456',
              'start_line' => 1,
              'start_byte' => 0,
              'language' => 'ruby',
              'score' => 0.7
            }
          ]
        end

        let(:grouping_query_result) do
          ::Ai::ActiveContext::Queries::Result.success(grouping_hits)
        end

        before do
          stub_feature_flags(
            post_process_semantic_code_search_add_score: true,
            post_process_semantic_code_search_overall_confidence: false,
            post_process_semantic_code_search_group_by_file: true
          )
          allow(query_obj).to receive(:filter).and_return(grouping_query_result)
        end

        it 'groups results by file path in text output' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          text_output = response[:content].first[:text]

          # Should show grouped format with file path and merged ranges
          expect(text_output).to include('app/services/user_service.rb')
          expect(text_output).to include('Lines 10-11')
          expect(text_output).to include('app/models/user.rb')
        end

        it 'includes grouped structure in structured data' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          structured = response[:structuredContent]

          # Should have 2 groups (2 unique files)
          expect(structured[:items].size).to eq(2)

          # First group should be user_service.rb (higher score)
          first_group = structured[:items].first
          expect(first_group[:path]).to eq('app/services/user_service.rb')
          expect(first_group[:score]).to eq(0.9)
          expect(first_group[:snippet_ranges]).to be_an(Array)
          # Ranges should include score (merged range uses max score)
          expect(first_group[:snippet_ranges].first[:score]).to eq(0.9)
        end

        it 'merges sequential line ranges within same file' do
          response = service.execute(request: nil, params: arguments)

          structured = response[:structuredContent]
          user_service_group = structured[:items].find { |g| g[:path] == 'app/services/user_service.rb' }

          # Lines 10 and 11 should be merged into a single range
          expect(user_service_group[:snippet_ranges].size).to eq(1)
          expect(user_service_group[:snippet_ranges].first[:start_line]).to eq(10)
          expect(user_service_group[:snippet_ranges].first[:end_line]).to eq(11)
        end
      end

      context 'when post_process_semantic_code_search_group_by_file feature flag is disabled' do
        let(:project_id) { project.id.to_s }

        before do
          stub_feature_flags(
            post_process_semantic_code_search_add_score: true,
            post_process_semantic_code_search_overall_confidence: false,
            post_process_semantic_code_search_group_by_file: false
          )
          allow(query_obj).to receive(:filter).and_return(query_result)
        end

        it 'does not group results in text output' do
          response = service.execute(request: nil, params: arguments)

          expect(response[:isError]).to be false
          text_output = response[:content].first[:text]

          # Should show flat format without grouping
          expect(text_output).not_to include('Lines ')
          expect(text_output).to match(/^\d+\. /)
        end

        it 'does not include snippet_ranges in structured data' do
          response = service.execute(request: nil, params: arguments)

          structured = response[:structuredContent]

          # Items should not have snippet_ranges/children keys
          structured[:items].each do |item|
            expect(item).not_to have_key(:snippet_ranges)
            expect(item).not_to have_key(:children)
          end
        end
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
        expect(result[:content].first[:text]).to eq("Tool execution failed: semantic_code_search: project not " \
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

      it 'returns Tool execution failed when project_id is not an string' do
        arguments = { arguments: { semantic_query: 'foo', project_id: 1 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Tool execution failed: project_id must be a string")
      end

      it 'returns validation error when limit is too big' do
        arguments = { arguments: { semantic_query: 'foo', project_id: project.id.to_s, limit: 101 } }
        result = service.execute(request: nil, params: arguments)

        expect(result[:isError]).to be true
        expect(result[:content].first[:text]).to eq("Validation error: limit is invalid")
      end

      it 'returns Tool execution failed error when project id not found' do
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

      it 'returns Tool execution failed error when project path not found' do
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

    context 'when Code Query is not available' do
      before do
        allow(::Ai::ActiveContext::Queries::Code).to receive(:available?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when Code Query is available' do
      before do
        allow(::Ai::ActiveContext::Queries::Code).to receive(:available?).and_return(true)
      end

      context 'when current_user is not set' do
        it { is_expected.to be(false) }
      end

      context 'when current_user is set' do
        before do
          service.set_cred(current_user: current_user)
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#filter_excluded_results' do
    let(:service) { described_class.new(name: service_name, version: '0.1.0') }

    let(:result_rb) { { 'path' => 'app/models/user.rb', 'content' => 'class User' } }
    let(:result_md) { { 'path' => 'README.md', 'content' => '# Project' } }
    let(:result_yml) { { 'path' => 'config/database.yml', 'content' => 'production:' } }
    let(:results) { [result_rb, result_md, result_yml] }

    subject(:filter_results) { service.send(:filter_excluded_results, results, project) }

    context 'with no exclusion rules' do
      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: [] }
        )
      end

      it 'returns all results' do
        is_expected.to match_array(results)
      end
    end

    context 'with exclusion rules matching some files' do
      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: ['*.md'] }
        )
      end

      it 'filters out excluded files' do
        is_expected.to match_array([result_rb, result_yml])
      end
    end

    context 'with exclusion rules matching all files' do
      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: ['*', '**/*'] }
        )
      end

      it 'returns empty array' do
        is_expected.to be_empty
      end
    end

    context 'when results array is empty' do
      let(:results) { [] }

      it 'returns empty array' do
        is_expected.to be_empty
      end
    end

    context 'when FileExclusionService returns error' do
      before do
        allow_next_instance_of(Ai::FileExclusionService) do |svc|
          allow(svc).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Test error')
          )
        end
      end

      it 'returns all results unfiltered' do
        is_expected.to match_array(results)
      end
    end

    context 'with results containing nil paths' do
      let(:result_nil) { { 'path' => nil, 'content' => 'something' } }
      let(:result_no_path) { { 'content' => 'no path key' } }
      let(:results) { [result_rb, result_nil, result_no_path] }

      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: ['*.rb'] }
        )
      end

      it 'handles nil paths gracefully' do
        is_expected.to match_array([result_nil, result_no_path])
      end
    end

    context 'when all results have nil or missing paths' do
      let(:result_nil1) { { 'path' => nil, 'content' => 'something' } }
      let(:result_nil2) { { 'content' => 'no path key' } }
      let(:results) { [result_nil1, result_nil2] }

      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: ['*.md'] }
        )
      end

      it 'returns all results when file_paths is empty' do
        is_expected.to match_array(results)
      end
    end
  end

  describe '#compute_confidence_level' do
    let(:service) { described_class.new(name: service_name, version: '0.1.0') }

    subject(:compute_confidence) { service.send(:compute_confidence_level, scores) }

    context 'with empty scores array' do
      let(:scores) { [] }

      it { is_expected.to eq(:unknown) }
    end

    context 'with single high score' do
      let(:scores) { [0.85] }

      it { is_expected.to eq(:high) }
    end

    context 'with single medium score' do
      let(:scores) { [0.60] }

      it { is_expected.to eq(:medium) }
    end

    context 'with single low score' do
      let(:scores) { [0.40] }

      it { is_expected.to eq(:low) }
    end

    context 'with steep drop-off (high confidence)' do
      let(:scores) { [0.85, 0.65, 0.60] }

      it { is_expected.to eq(:high) }
    end

    context 'with gradual decline (medium confidence)' do
      let(:scores) { [0.75, 0.70, 0.65] }

      it { is_expected.to eq(:medium) }
    end

    context 'with flat distribution of low scores' do
      let(:scores) { [0.45, 0.43, 0.42] }

      it { is_expected.to eq(:low) }
    end

    context 'with score exactly at high threshold' do
      let(:scores) { [0.75, 0.59] }

      it { is_expected.to eq(:high) }
    end

    context 'with score exactly at medium threshold' do
      let(:scores) { [0.50, 0.48] }

      it { is_expected.to eq(:medium) }
    end

    context 'with score just below medium threshold' do
      let(:scores) { [0.49, 0.48] }

      it { is_expected.to eq(:low) }
    end

    context 'with high top score but small gap' do
      let(:scores) { [0.80, 0.78] }

      it { is_expected.to eq(:medium) }
    end
  end

  describe '#group_results_by_file' do
    let(:service) { described_class.new(name: service_name, version: '0.1.0') }

    subject(:grouped) { service.send(:group_results_by_file, hits) }

    context 'with empty hits' do
      let(:hits) { [] }

      it { is_expected.to eq([]) }
    end

    context 'with single hit' do
      let(:hits) do
        [
          {
            'path' => 'server.rb',
            'project_id' => 1000,
            'language' => 'ruby',
            'blob_id' => 'abc123',
            'content' => 'def run',
            'start_line' => 10,
            'score' => 0.85
          }
        ]
      end

      it 'returns a single group' do
        expect(grouped.size).to eq(1)
        expect(grouped.first[:path]).to eq('server.rb')
        expect(grouped.first[:score]).to eq(0.85)
        expect(grouped.first[:snippet_ranges].size).to eq(1)
      end
    end

    context 'with multiple hits from same file' do
      let(:hits) do
        [
          {
            'path' => 'server.rb',
            'project_id' => 1000,
            'language' => 'ruby',
            'blob_id' => 'abc123',
            'content' => 'def run',
            'start_line' => 10,
            'score' => 0.85
          },
          {
            'path' => 'server.rb',
            'project_id' => 1000,
            'language' => 'ruby',
            'blob_id' => 'abc123',
            'content' => 'def stop',
            'start_line' => 20,
            'score' => 0.75
          }
        ]
      end

      it 'groups them into one result' do
        expect(grouped.size).to eq(1)
        expect(grouped.first[:path]).to eq('server.rb')
        expect(grouped.first[:score]).to eq(0.85) # max score
        expect(grouped.first[:snippet_ranges].size).to eq(2)
        # Each range includes its score
        expect(grouped.first[:snippet_ranges].pluck(:score)).to contain_exactly(0.85, 0.75)
      end
    end

    context 'with hits from different files' do
      let(:hits) do
        [
          {
            'path' => 'server.rb',
            'project_id' => 1000,
            'language' => 'ruby',
            'blob_id' => 'abc123',
            'content' => 'def run',
            'start_line' => 10,
            'score' => 0.85
          },
          {
            'path' => 'client.rb',
            'project_id' => 1000,
            'language' => 'ruby',
            'blob_id' => 'def456',
            'content' => 'def connect',
            'start_line' => 5,
            'score' => 0.70
          }
        ]
      end

      it 'creates separate groups sorted by score' do
        expect(grouped.size).to eq(2)
        expect(grouped.first[:path]).to eq('server.rb') # higher score first
        expect(grouped.last[:path]).to eq('client.rb')
      end
    end
  end

  describe '#merge_sequential_ranges' do
    let(:service) { described_class.new(name: service_name, version: '0.1.0') }

    subject(:merged) { service.send(:merge_sequential_ranges, sorted_hits) }

    context 'with empty hits' do
      let(:sorted_hits) { [] }

      it { is_expected.to eq([]) }
    end

    context 'with non-sequential ranges' do
      let(:sorted_hits) do
        [
          { 'start_line' => 10, 'content' => 'line 10' },
          { 'start_line' => 20, 'content' => 'line 20' }
        ]
      end

      it 'keeps them separate' do
        expect(merged.size).to eq(2)
        expect(merged[0][:start_line]).to eq(10)
        expect(merged[1][:start_line]).to eq(20)
      end
    end

    context 'with sequential ranges (line 10 followed by line 11)' do
      let(:sorted_hits) do
        [
          { 'start_line' => 10, 'content' => 'line 10' },
          { 'start_line' => 11, 'content' => 'line 11' }
        ]
      end

      it 'merges them into one range' do
        expect(merged.size).to eq(1)
        expect(merged.first[:start_line]).to eq(10)
        expect(merged.first[:content]).to eq("line 10\nline 11")
      end
    end

    context 'with mixed sequential and non-sequential ranges' do
      let(:sorted_hits) do
        [
          { 'start_line' => 10, 'content' => 'line 10' },
          { 'start_line' => 11, 'content' => 'line 11' },
          { 'start_line' => 20, 'content' => 'line 20' },
          { 'start_line' => 21, 'content' => 'line 21' }
        ]
      end

      it 'merges sequential ranges separately' do
        expect(merged.size).to eq(2)
        expect(merged[0][:start_line]).to eq(10)
        expect(merged[0][:content]).to eq("line 10\nline 11")
        expect(merged[1][:start_line]).to eq(20)
        expect(merged[1][:content]).to eq("line 20\nline 21")
      end
    end
  end

  context 'when there is a version without its own perform method' do
    before do
      project.add_developer(current_user)

      allow(described_class).to receive(:available_versions).and_return(['0.1.0', '0.2.0'])
      allow(described_class).to receive(:version_exists?).with('0.2.0').and_return(true)
      allow(described_class).to receive(:version_metadata).with('0.2.0')
        .and_return(described_class.version_metadata('0.1.0'))
    end

    let(:service) do
      described_class.new(name: service_name, version: '0.2.0').tap do |s|
        s.set_cred(current_user: current_user, access_token: oauth_token)
      end
    end

    it 'calls the perform_0_1_0 method on execute' do
      expect(service).to receive(:perform_0_1_0)

      params = {
        arguments: {
          semantic_query: 'the query string',
          project_id: project.id.to_s
        }
      }

      service.execute(request: nil, params: params)
    end
  end
end
