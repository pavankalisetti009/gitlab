# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::Deleter, feature_category: :global_search do
  let_it_be(:connection) { create(:ai_active_context_connection) }
  let_it_be(:collection) do
    create(:ai_active_context_collection, name: 'gitlab_active_context_code', connection: connection)
  end

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.first_owner }

  let_it_be_with_reload(:repository) do
    create(:ai_active_context_code_repository, active_context_connection: connection, project: project)
  end

  let(:adapter) do
    instance_double(::ActiveContext::Databases::Elasticsearch::Adapter, name: 'elasticsearch', connection: connection)
  end

  let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil, error: nil) }

  let(:deleter) { described_class.new(repository) }

  subject(:run) { deleter.run }

  before do
    allow(::ActiveContext).to receive(:adapter).and_return(adapter)
    allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
  end

  def build_log_payload(message, extra_params = {})
    {
      class: described_class.to_s,
      message: message,
      ai_active_context_code_repository_id: repository.id,
      project_id: repository.project.id
    }.merge(extra_params).stringify_keys
  end

  describe '.run!' do
    it 'delegates to the instance method #run' do
      deleter_double = instance_double(described_class, run: nil)
      allow(described_class).to receive(:new).with(repository).and_return(deleter_double)

      expect(deleter_double).to receive(:run)
      described_class.run!(repository)
    end
  end

  describe '#run' do
    let(:env_vars) { { "GITLAB_INDEXER_MODE" => "chunk" } }
    let(:expected_options) do
      {
        project_id: project.id,
        partition_name: collection.name,
        partition_number: collection.partition_for(project.id),
        timeout: described_class::TIMEOUT,
        operation: 'delete_project'
      }
    end

    let(:expected_command) do
      [
        Gitlab.config.elasticsearch.indexer_path,
        '-adapter', 'elasticsearch',
        '-connection', ::Gitlab::Json.generate(connection.options),
        '-options', ::Gitlab::Json.generate(expected_options)
      ]
    end

    context 'when adapter is available' do
      context 'when delete command succeeds' do
        before do
          allow(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(["Delete successful\n", 0])
        end

        it 'calls the indexer with the correct command' do
          expect(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(["Delete successful\n", 0])

          run
        end

        it 'logs success message' do
          expect(logger).to receive(:info).with(
            build_log_payload('Delete successful', status: 0)
          )

          run
        end

        it 'does not raise an error' do
          expect { run }.not_to raise_error
        end

        it 'does not update the repository last_commit' do
          expect(repository).not_to receive(:update!)

          run
        end
      end

      context 'when delete command fails' do
        let(:error_output) { "Failed to delete project embeddings\nConnection timeout" }

        before do
          allow(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return([error_output, 1])
        end

        it 'logs error message with details' do
          expect(logger).to receive(:error).with(
            build_log_payload(
              'Delete failed',
              status: 1,
              error_details: error_output
            )
          )

          expect { run }.to raise_error(described_class::Error)
        end

        it 'raises an exception with error details' do
          expect { run }.to raise_error(
            described_class::Error,
            "Delete failed with status: 1 and error: #{error_output}"
          )
        end
      end

      context 'with elasticsearch adapter connection options' do
        before do
          connection.reload.update!(
            adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
            options: {
              url: [
                { scheme: "http", host: "localhost", port: 9200 },
                { scheme: "http", host: "localhost", port: 9200, user: 'dummy', password: 'pass123' }
              ]
            }
          )
        end

        let(:adapter) do
          ::ActiveContext::Databases::Elasticsearch::Adapter.new(
            connection,
            options: connection.options
          )
        end

        let(:expected_connection_command_arg) do
          ::Gitlab::Json.generate({
            url: [
              'http://localhost:9200/',
              'http://dummy:pass123@localhost:9200/'
            ]
          })
        end

        let(:expected_command) do
          [
            Gitlab.config.elasticsearch.indexer_path,
            '-adapter', 'elasticsearch',
            '-connection', expected_connection_command_arg,
            '-options', ::Gitlab::Json.generate(expected_options)
          ]
        end

        it 'formats connection options correctly for elasticsearch' do
          expect(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(["Delete successful\n", 0])

          run
        end
      end

      context 'when the project is deleted' do
        before do
          project.destroy!
        end

        it 'formats connection options correctly for elasticsearch' do
          expect(repository.project).to be_nil

          expect(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(["Delete successful\n", 0])

          run
        end
      end
    end

    context 'when adapter is not available' do
      before do
        allow(::ActiveContext).to receive(:adapter).and_return(nil)
      end

      it 'raises an error' do
        expect { run }.to raise_error(described_class::Error, 'Adapter not set')
      end
    end
  end
end
