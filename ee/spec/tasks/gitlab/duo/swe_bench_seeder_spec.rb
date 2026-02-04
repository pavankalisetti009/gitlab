# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:duo:swe_bench_seeder', :silence_stdout, feature_category: :duo_chat do
  let(:langchain_endpoint) { 'https://api.smith.langchain.com' }
  let(:langchain_api_key) { 'test_api_key' }
  let(:dataset_name) { 'duo_workflow.swe-bench-verified-test.1' }
  let(:dataset_id) { '6cd898d8-3b3c-49d4-bfd5-944f83bea1f2' }
  let(:split_name) { 'validation_stratified_b06f4db4_p20' }
  let(:organization) { create(:organization) }
  let!(:user) { create(:user, organizations: [organization], username: 'root') }

  let(:run) { run_rake_task('gitlab:duo:swe_bench_seeder') }
  let(:run_with_projects) { run_rake_task('gitlab:duo:swe_bench_seeder', ['flask, django']) }
  let(:run_with_single_project) { run_rake_task('gitlab:duo:swe_bench_seeder', ['flask']) }

  before do
    Rake.application.rake_require 'tasks/gitlab/duo'
    stub_env('LANGCHAIN_ENDPOINT', langchain_endpoint)
    stub_env('LANGCHAIN_API_KEY', langchain_api_key)
    stub_env('LANGSMITH_DATASET_NAME', dataset_name)
    stub_env('LANGSMITH_DATASET_ID', dataset_id)
    stub_env('LANGSMITH_SPLIT_NAME', split_name)
  end

  context 'when configuration or API errors occur' do
    it 'handles missing LANGCHAIN_API_KEY' do
      stub_env('LANGCHAIN_API_KEY', nil)
      expect { run }.to output(/Missing LANGCHAIN_API_KEY environment variable!/).to_stdout
    end

    it 'handles API request failures' do
      stub_request(:get, "#{langchain_endpoint}/api/v1/examples")
        .with(
          headers: { 'x-api-key' => langchain_api_key, 'Content-Type' => 'application/json' },
          query: { dataset: dataset_id, splits: split_name }
        )
        .to_return(status: 401, body: 'Unauthorized')

      expect { run }.to output(/Failed to fetch dataset: 401/).to_stdout
    end

    it 'handles unexpected errors gracefully' do
      allow(Gitlab::HTTP).to receive(:get).and_raise(StandardError.new("Network failure"))
      expect { run }.to output(/Error fetching dataset from LangSmith: Network failure/).to_stdout
    end
  end

  context 'when the dataset contains examples' do
    let(:example_response) do
      [
        {
          'inputs' => {
            'repo' => 'pallets/flask',
            'problem_statement' => "Fix bug in Flask\n\nDescription of the bug to fix."
          }
        },
        {
          'inputs' => {
            'repo' => 'django/django',
            'problem_statement' => "Add feature to Django\n\nDescription of the feature to add."
          }
        }
      ]
    end

    before do
      stub_request(:get, "#{langchain_endpoint}/api/v1/examples")
        .with(
          headers: { 'x-api-key' => langchain_api_key, 'Content-Type' => 'application/json' },
          query: { dataset: dataset_id, splits: split_name }
        )
        .to_return(status: 200, body: example_response.to_json)

      # Stub project creation to avoid actual cloning
      allow_next_instance_of(Projects::CreateService) do |service|
        allow(service).to receive(:execute).and_return(
          create(:project, :repository, namespace: create(:group))
        )
      end

      # Stub issue creation - ensure issue is associated with the project
      allow_next_instance_of(Issues::CreateService) do |service|
        allow(service).to receive(:execute) do
          project = service.container
          issue = create(:issue, project: project)
          ServiceResponse.success(payload: { issue: issue })
        end
      end
    end

    it 'processes the dataset and creates issues without saving to LangSmith' do
      stub_env('SAVE_TO_LANGSMITH', nil)
      expect(Gitlab::Duo::Developments::SweBenchSeeder).not_to receive(:save_issue_urls_to_langsmith)

      expect { run }.to output(/Processing examples from SWE Bench Dataset/).to_stdout
    end

    it 'processes the dataset, creates issues, and saves to LangSmith with custom name' do
      custom_dataset_name = 'my-custom-dataset-name'
      stub_env('SAVE_TO_LANGSMITH', custom_dataset_name)

      stub_request(:get, "#{langchain_endpoint}/api/v1/datasets")
        .with(
          headers: { 'x-api-key' => langchain_api_key, 'Content-Type' => 'application/json' },
          query: { name: custom_dataset_name }
        )
        .to_return(status: 200, body: [].to_json)

      stub_request(:post, "#{langchain_endpoint}/api/v1/datasets")
        .with(
          headers: { 'x-api-key' => langchain_api_key, 'Content-Type' => 'application/json' },
          body: {
            name: custom_dataset_name,
            description: "Issue URLs created by SWE Bench seeder"
          }.to_json
        )
        .to_return(status: 200, body: { id: 'new-dataset-id', name: custom_dataset_name }.to_json)

      stub_request(:post, "#{langchain_endpoint}/api/v1/examples")
        .with(
          headers: { 'x-api-key' => langchain_api_key, 'Content-Type' => 'application/json' },
          body: hash_including(dataset_id: 'new-dataset-id')
        )
        .to_return(status: 200, body: {}.to_json)

      expect(Gitlab::Duo::Developments::SweBenchSeeder).to receive(:save_issue_urls_to_langsmith)
        .with(array_including(hash_including(:inputs, :outputs)), custom_dataset_name)
        .and_call_original

      expect { run }.to output(/Saving.*issue URLs to LangSmith dataset: #{custom_dataset_name}/).to_stdout
    end

    it 'handles single project filter' do
      expect(Gitlab::Duo::Developments::SweBenchSeeder).to receive(:seed)
        .with(project_filter: %w[flask])
        .and_call_original

      expect { run_with_single_project }.to output(/Filtered to.*repositories matching filter/).to_stdout
    end
  end
end
