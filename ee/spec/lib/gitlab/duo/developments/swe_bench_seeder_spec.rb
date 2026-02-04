# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder, feature_category: :duo_chat do
  describe '.seed' do
    let(:user) { instance_double(User) }
    let(:parent_group) { instance_double(Group) }
    let(:subgroup) { instance_double(Group, full_path: 'swe-bench/test') }
    let(:project) { instance_double(Project, full_path: 'swe-bench/test/repo', persisted?: true) }
    let(:issue) { instance_double(Issue, iid: 1, title: 'Test Issue') }
    let(:config_class) { Gitlab::Duo::Developments::SweBenchSeeder::Config }
    let(:group_manager) { Gitlab::Duo::Developments::SweBenchSeeder::GroupManager }
    let(:issue_manager) { Gitlab::Duo::Developments::SweBenchSeeder::IssueManager }
    let(:repository_manager) { Gitlab::Duo::Developments::SweBenchSeeder::RepositoryManager }
    let(:dataset_processor) { Gitlab::Duo::Developments::SweBenchSeeder::DatasetProcessor }
    let(:langsmith_client) { Gitlab::Duo::Developments::SweBenchSeeder::LangsmithClient }

    before do
      allow(User).to receive(:find_by_username).with('root').and_return(user)
      allow(group_manager).to receive_messages(find_or_create_parent_group: parent_group,
        find_or_create_subgroup: subgroup)
      allow(config_class).to receive_messages(seed_base_url: 'http://test.example.com', source_base_url: 'https://github.com')
      allow(issue_manager).to receive(:delete_all_issues_in_subgroup)
      # rubocop:disable RSpec/VerifiedDoubles -- UrlHelpers is a module, not a class
      allow(Rails.application.routes).to receive(:url_helpers).and_return(
        double(project_issue_url: 'http://test.example.com/swe-bench/test/repo/-/issues/1')
      )
      # rubocop:enable RSpec/VerifiedDoubles
    end

    context 'when dataset is empty' do
      before do
        allow(dataset_processor).to receive(:fetch_dataset_from_langsmith).and_return([[], 'test-dataset', 'split'])
      end

      it 'returns early without processing' do
        expect(repository_manager).not_to receive(:clone_repository)

        described_class.seed
      end
    end

    context 'when project clone returns nil or unpersisted project' do
      let(:dataset) do
        [{ 'inputs' => { 'repo' => 'org/repo', 'problem_statement' => 'Fix bug', 'base_commit' => 'abc123' },
           'outputs' => {} }]
      end

      before do
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [dataset, 'test-dataset',
          'split'], group_examples_by_repo: { 'org/repo' => dataset }, filter_by_project: { 'org/repo' => dataset })
      end

      it 'skips when clone returns nil' do
        allow(repository_manager).to receive(:clone_repository).and_return(nil)
        expect(issue_manager).not_to receive(:create_issue_from_problem_statement)

        described_class.seed
      end

      it 'skips when project is not persisted' do
        allow(repository_manager).to receive(:clone_repository).and_return(instance_double(Project, persisted?: false))
        expect(issue_manager).not_to receive(:create_issue_from_problem_statement)

        described_class.seed
      end
    end

    context 'when example has no problem_statement' do
      let(:dataset) do
        [
          { 'inputs' => { 'repo' => 'org/repo', 'base_commit' => 'abc123' }, 'outputs' => {} },
          { 'inputs' => { 'repo' => 'org/repo', 'problem_statement' => nil, 'base_commit' => 'def456' },
            'outputs' => {} }
        ]
      end

      before do
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [dataset, 'test-dataset',
          'split'], group_examples_by_repo: { 'org/repo' => dataset }, filter_by_project: { 'org/repo' => dataset })
        allow(repository_manager).to receive(:clone_repository).and_return(project)
      end

      it 'skips examples without problem_statement' do
        expect(issue_manager).not_to receive(:create_issue_from_problem_statement)

        described_class.seed
      end
    end

    context 'when issue creation returns nil' do
      let(:dataset) do
        [{ 'inputs' => { 'repo' => 'org/repo', 'problem_statement' => 'Fix bug', 'base_commit' => 'abc123' },
           'outputs' => {} }]
      end

      before do
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [dataset, 'test-dataset',
          'split'], group_examples_by_repo: { 'org/repo' => dataset }, filter_by_project: { 'org/repo' => dataset })
        allow(repository_manager).to receive(:clone_repository).and_return(project)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(nil)
      end

      it 'skips to the next example without adding to issue data' do
        described_class.seed

        expect(issue_manager).to have_received(:create_issue_from_problem_statement).once
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(dataset_processor).to receive(:fetch_dataset_from_langsmith).and_raise(StandardError, 'Test error')
      end

      it 'logs the error and re-raises it' do
        expect { described_class.seed }.to raise_error(StandardError, 'Test error')
          .and output(/Error seeding SWE Bench structure: Test error/).to_stdout
      end
    end

    context 'when seeding completes successfully' do
      let(:dataset) do
        [{ 'inputs' => { 'repo' => 'org/repo', 'problem_statement' => 'Fix bug', 'base_commit' => 'abc123' },
           'outputs' => { 'solution' => 'test' } }]
      end

      before do
        stub_env('SAVE_TO_LANGSMITH', nil)
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [dataset, 'test-dataset',
          'split'], group_examples_by_repo: { 'org/repo' => dataset }, filter_by_project: { 'org/repo' => dataset })
        allow(repository_manager).to receive(:clone_repository).and_return(project)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(issue)
      end

      it 'creates issues and tracks statistics' do
        expect { described_class.seed }.to output(/SEEDING STATISTICS/).to_stdout
      end
    end

    context 'when SAVE_TO_LANGSMITH is set' do
      let(:dataset) do
        [{ 'inputs' => { 'repo' => 'org/repo', 'problem_statement' => 'Fix bug', 'base_commit' => 'abc123' },
           'outputs' => { 'solution' => 'test' } }]
      end

      before do
        stub_env('SAVE_TO_LANGSMITH', 'target-dataset')
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [dataset, 'test-dataset',
          'split'], group_examples_by_repo: { 'org/repo' => dataset }, filter_by_project: { 'org/repo' => dataset })
        allow(repository_manager).to receive(:clone_repository).and_return(project)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(issue)
        allow(langsmith_client).to receive(:save_issue_urls_to_langsmith)
      end

      it 'saves issue data to LangSmith' do
        described_class.seed

        expect(langsmith_client).to have_received(:save_issue_urls_to_langsmith)
      end
    end
  end

  describe '.langsmith_request' do
    let(:endpoint) { 'https://example.langsmith.test' }
    let(:api_key) { 'test-api-key' }
    let(:path) { '/api/v1/examples' }
    let(:query) { { dataset: '123', splits: 'abc' } }

    subject(:langsmith_request) do
      Gitlab::Duo::Developments::SweBenchSeeder::Config.langsmith_request(
        method: method,
        path: path,
        api_key: api_key,
        query: query,
        body: body
      )
    end

    before do
      stub_env('LANGCHAIN_ENDPOINT', endpoint)
    end

    context 'when method is GET' do
      let(:method) { :get }
      let(:body) { nil }

      it 'delegates to Gitlab::HTTP.get with expected url, headers, and query' do
        expected_headers = {
          'x-api-key' => api_key,
          'Content-Type' => 'application/json'
        }

        expect(Gitlab::HTTP).to receive(:get).with(
          "#{endpoint}#{path}",
          headers: expected_headers,
          query: query
        )

        langsmith_request
      end
    end

    context 'when method is POST' do
      let(:method) { :post }
      let(:body) { { dataset_id: '123', inputs: { issue_url: 'http://example.test' }, outputs: {} } }

      it 'delegates to Gitlab::HTTP.post with expected url, headers, query, and json body' do
        expected_headers = {
          'x-api-key' => api_key,
          'Content-Type' => 'application/json'
        }

        expect(Gitlab::HTTP).to receive(:post).with(
          "#{endpoint}#{path}",
          headers: expected_headers,
          query: query,
          body: body.to_json
        )

        langsmith_request
      end
    end

    context 'when method is POST without body' do
      let(:method) { :post }
      let(:body) { nil }

      it 'delegates to Gitlab::HTTP.post with nil body' do
        expected_headers = {
          'x-api-key' => api_key,
          'Content-Type' => 'application/json'
        }

        expect(Gitlab::HTTP).to receive(:post).with(
          "#{endpoint}#{path}",
          headers: expected_headers,
          query: query,
          body: nil
        )

        langsmith_request
      end
    end

    context 'when method is DELETE' do
      let(:method) { :delete }
      let(:body) { nil }

      it 'delegates to Gitlab::HTTP.delete with expected url, headers, and query' do
        expected_headers = {
          'x-api-key' => api_key,
          'Content-Type' => 'application/json'
        }

        expect(Gitlab::HTTP).to receive(:delete).with(
          "#{endpoint}#{path}",
          headers: expected_headers,
          query: query
        )

        langsmith_request
      end
    end

    context 'when method is unsupported' do
      let(:method) { :patch }
      let(:body) { nil }

      it 'raises an ArgumentError' do
        expect { langsmith_request }.to raise_error(ArgumentError, /Unsupported HTTP method/)
      end
    end
  end
end
