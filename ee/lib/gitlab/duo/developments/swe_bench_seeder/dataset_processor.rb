# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class SweBenchSeeder
        class DatasetProcessor
          def self.fetch_dataset_from_langsmith
            # Optional overrides:
            # - LANGSMITH_DATASET_NAME
            # - LANGSMITH_DATASET_ID
            # - LANGSMITH_SPLIT_NAME
            default_dataset_name = 'duo_workflow.swe-bench-verified-test.1'
            default_dataset_id = '6cd898d8-3b3c-49d4-bfd5-944f83bea1f2'
            default_split_name = 'validation_stratified_b06f4db4_p20'

            dataset_name = ENV.fetch('LANGSMITH_DATASET_NAME', default_dataset_name)
            dataset_id = ENV.fetch('LANGSMITH_DATASET_ID', default_dataset_id)
            split_name = ENV.fetch('LANGSMITH_SPLIT_NAME', default_split_name)

            langchain_api_key = Config.langsmith_api_key!(
              missing_message: "Missing LANGCHAIN_API_KEY environment variable!"
            )
            return [[], dataset_name, split_name] unless langchain_api_key

            response = Config.langsmith_request(
              method: :get,
              path: '/api/v1/examples',
              query: { dataset: dataset_id, splits: split_name },
              api_key: langchain_api_key
            )

            unless response.success?
              puts "Failed to fetch dataset: #{response.code} #{response.message}"
              puts "Response body: #{response.body}"
              return [[], dataset_name, split_name]
            end

            # Parse JSON response (not JSONL)
            response_data = ::Gitlab::Json.safe_parse(response.body)

            # Extract examples from response (structure may vary, but typically it's an array or has an 'examples' key)
            examples = if response_data.is_a?(Array)
                         response_data
                       elsif response_data['examples']
                         response_data['examples']
                       elsif response_data['data']
                         response_data['data']
                       end || response_data

            # Process all examples from the split
            dataset = examples.is_a?(Array) ? examples : [examples]
            [dataset, dataset_name, split_name]
          rescue StandardError => e
            puts "Error fetching dataset from LangSmith: #{e.message}"
            puts e.backtrace.first(5).join("\n")
            [[], dataset_name, split_name]
          end

          def self.group_examples_by_repo(dataset)
            examples_by_repo = {}
            dataset.each do |example|
              repo = example['inputs']&.[]('repo')
              if repo
                examples_by_repo[repo] ||= []
                examples_by_repo[repo] << example
              else
                puts "Warning: Skipping example with no repo field"
              end
            end
            examples_by_repo
          end

          def self.filter_by_project(examples_by_repo, project_filter)
            return examples_by_repo unless project_filter&.any?

            filtered_repos = {}
            project_filter.each do |filter|
              # Match full repo path (e.g., "pallets/flask") or just project name (e.g., "flask")
              matching_repos = examples_by_repo.keys.select do |repo|
                repo == filter || repo.end_with?("/#{filter}")
              end
              matching_repos.each do |repo|
                filtered_repos[repo] = examples_by_repo[repo]
              end
            end
            puts "Filtered to #{filtered_repos.keys.size} repositories matching filter"
            filtered_repos
          end
        end
      end
    end
  end
end
