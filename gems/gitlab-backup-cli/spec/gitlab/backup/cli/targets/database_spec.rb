# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Backup::Cli::Targets::Database do
  let(:context) { Gitlab::Backup::Cli::Context.build }
  let(:database) { described_class.new(context) }

  describe '#dump' do
    let(:destination) { '/path/to/destination' }
    # let(:backup_connection) { double('backup_connection') }
    # let(:database_configuration) { double('database_configuration') }
    let(:pg_env_variables) { { 'PGHOST' => 'localhost' } }
    let(:activerecord_variables) { { database: 'gitlabhq_production' } }

    before do
      # allow(backup_connection).to receive(:database_configuration).and_return(database_configuration)
      # allow(database_configuration).to receive(:pg_env_variables).and_return(pg_env_variables)
      # allow(database_configuration).to receive(:activerecord_variables).and_return(activerecord_variables)
      allow(Gitlab::Backup::Cli::Database::EachDatabase).to receive(:each_connection).and_yield(nil, 'main')
      # allow(Gitlab::Backup::Cli::Database::Connection).to receive(:new).with('main').and_return(backup_connection)
    end

    it 'creates the destination directory' do
      expect(FileUtils).to receive(:mkdir_p).with(destination)
      database.dump(destination)
    end

    # it 'dumps the database' do
    #   dump_double = double('dump')
    #   expect(Gitlab::Backup::Cli::Database::Postgres).to receive(:new).and_return(dump_double)
    #   expect(dump_double).to receive(:dump)
    #   database.dump(destination)
    # end

    # it 'releases the snapshot after dumping' do
    #   expect(backup_connection).to receive(:release_snapshot!)
    #   database.dump(destination)
    # end

    # it 'raises an error if the dump fails' do
    #   allow(Gitlab::Backup::Cli::Database::Postgres).to receive(:new).and_return(double('dump', dump: false))
    #   expect { database.dump(destination) }.to raise_error(Gitlab::Backup::Cli::Errors::DatabaseBackupError)
    # end
  end

  # describe '#restore' do
  #   let(:source) { '/path/to/source' }
  #   let(:backup_connection) { double('backup_connection') }
  #   let(:database_configuration) { double('database_configuration') }
  #   let(:pg_env_variables) { { 'PGHOST' => 'localhost' } }
  #   let(:activerecord_variables) { { database: 'gitlabhq_production' } }

  #   before do
  #     allow(backup_connection).to receive(:database_configuration).and_return(database_configuration)
  #     allow(database_configuration).to receive(:pg_env_variables).and_return(pg_env_variables)
  #     allow(database_configuration).to receive(:activerecord_variables).and_return(activerecord_variables)
  #     allow(Gitlab::Backup::Cli::Database::Connection).to receive(:new).with(:main).and_return(backup_connection)
  #   end

  #   it 'drops all tables before restoring' do
  #     expect(database).to receive(:drop_tables).with(:main)
  #     database.restore(source)
  #   end

  #   it 'restores the database' do
  #     allow(File).to receive(:exist?).and_return(true)
  #     expect(database).to receive(:with_transient_pg_env).and_yield
  #     database.restore(source)
  #   end

  #   it 'raises an error if the database file does not exist' do
  #     allow(File).to receive(:exist?).and_return(false)
  #     expect { database.restore(source) }.to raise_error(Gitlab::Backup::Cli::Errors::DatabaseBackupError)
  #   end
  # end
end
