# frozen_string_literal: true

RSpec.describe Gitlab::Backup::Cli::Services::Databases do
  let(:context) { build_test_context }

  subject(:databases) { described_class.new(context) }

  describe '#entries' do
    context 'with missing database configuration' do
      it 'raises an error' do
        allow(context).to receive(:database_config_file_path).and_return('/tmp/invalid')

        expect { databases.entries }.to raise_error(Gitlab::Backup::Cli::Errors::DatabaseConfigMissingError)
      end
    end

    it 'returns a collection of Database objects' do
      expect(databases.entries).to all(be_a(Gitlab::Backup::Cli::Services::Database))
    end
  end

  describe '#each' do
    it 'returns an enumerator when no block is given' do
      expect(databases.each).to be_an(Enumerator)
      expect(databases.each.map).to all(be_a(Gitlab::Backup::Cli::Services::Database))
    end

    it 'yields a collection of database objects' do
      expect { |b| databases.each(&b) }.to yield_successive_args(*databases.entries)
    end
  end
end
