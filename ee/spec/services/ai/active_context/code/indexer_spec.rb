# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::Indexer, feature_category: :global_search do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:connection) { create(:ai_active_context_connection) }
  let_it_be(:repository) do
    create(:ai_active_context_code_repository, active_context_connection: connection, project: project)
  end

  let_it_be(:collection) do
    create(:ai_active_context_collection, name: 'gitlab_active_context_code', connection: connection)
  end

  let(:adapter) do
    instance_double(::ActiveContext::Databases::Elasticsearch::Adapter, name: 'elasticsearch', connection: connection)
  end

  let(:indexer) { described_class.new(repository) }
  let(:block) { proc { |id| processed_ids << id } }
  let(:processed_ids) { [] }

  subject(:run) { indexer.run(&block) }

  before do
    allow(::ActiveContext).to receive(:adapter).and_return(adapter)
    allow(indexer).to receive(:to_commit).and_return(instance_double(Commit, id: '000'))
  end

  describe '.run!' do
    it 'delegates to the instance method #run' do
      indexer_double = instance_double(described_class, run: nil)
      allow(described_class).to receive(:new).with(repository).and_return(indexer_double)

      expect(indexer_double).to receive(:run).and_yield('test_value')
      described_class.run!(repository, &block)
    end
  end

  describe '#run' do
    context 'when adapter is available' do
      context 'when command is executed' do
        let(:env_vars) { { "GITLAB_INDEXER_MODE" => "chunk" } }
        let(:expected_options) do
          {
            from_sha: Gitlab::Git::SHA1_BLANK_SHA,
            to_sha: '000',
            project_id: project.id,
            partition_name: collection.name,
            partition_number: collection.partition_for(project.id),
            gitaly_config: {
              address: Gitlab::GitalyClient.address(project.repository_storage),
              storage: project.repository_storage,
              relative_path: project.repository.relative_path,
              project_path: project.full_path
            },
            timeout: described_class::TIMEOUT
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

        it 'calls the indexer with the correct command' do
          expect(Gitlab::Popen).to receive(:popen_with_streaming)
            .with(expected_command, nil, env_vars)
            .and_return(0)

          run
        end
      end

      context 'when indexer command succeeds' do
        before do
          allow(Gitlab::Popen).to receive(:popen_with_streaming) do |_cmd, _dir, _env, &stream_block|
            stream_block.call(:stdout, "--section-start--\n")
            stream_block.call(:stdout, "version,build_time\n")
            stream_block.call(:stdout, "v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC\n")
            stream_block.call(:stdout, "--section-start--\n")
            stream_block.call(:stdout, "id\n")
            stream_block.call(:stdout, "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef\n")
            stream_block.call(:stdout, "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890\n")
            0
          end
        end

        it 'processes streamed output and calls block for each hash ID' do
          expect(repository).to receive(:update!).with(last_commit: '000')

          run

          expect(processed_ids).to eq(%w[
            1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
            abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
          ])
        end
      end

      context 'when indexer command fails' do
        before do
          allow(Gitlab::Popen).to receive(:popen_with_streaming) do |_cmd, _dir, _env, &stream_block|
            stream_block.call(:stderr, "Command failed with error\n")
            stream_block.call(:stderr, "Additional error details\n")
            1
          end
        end

        it 'raises an exception with stderr output' do
          expect { run }.to raise_error(
            described_class::Error,
            "Indexer failed with status: 1 and error: Command failed with error\nAdditional error details\n"
          )
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
