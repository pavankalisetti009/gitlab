# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::SpecHelpers::V1::TableHelpers, feature_category: :database do
  let(:test_class) do
    Class.new do
      include MigrationsHelpers
      include Gitlab::BackgroundMigration::SpecHelpers::V1::TableHelpers

      # Simulate RSpec metadata for migration schema
      def self.metadata
        { migration: :main }
      end
    end
  end

  let(:instance) { test_class.new }

  describe 'dynamic table access' do
    it 'creates table helpers on demand' do
      users_table = instance.users

      expect(users_table).to be_a(Class)
      expect(users_table.table_name).to eq('users')
    end

    it 'memoizes table helpers' do
      first_access = instance.users
      second_access = instance.users

      expect(first_access).to be(second_access)
    end

    it 'creates different helpers for different tables' do
      users_table = instance.users
      projects_table = instance.projects

      expect(users_table.table_name).to eq('users')
      expect(projects_table.table_name).to eq('projects')
      expect(users_table).not_to be(projects_table)
    end

    it 'allows creating records' do
      organizations_table = instance.organizations

      organization = organizations_table.create!(name: 'test-org', path: 'test-org')

      expect(organization).to be_persisted
      expect(organization.name).to eq('test-org')
    end
  end

  describe '.configure_table' do
    context 'with custom primary key' do
      before do
        test_class.configure_table :users, primary_key: :custom_id
      end

      it 'uses the configured primary key' do
        users_table = instance.users

        expect(users_table.primary_key).to eq('custom_id')
      end
    end

    context 'with custom database' do
      before do
        test_class.configure_table :custom_table, database: :main
      end

      it 'uses the configured database' do
        # The table helper should be created without error
        expect { instance.custom_table }.not_to raise_error
      end
    end
  end

  describe 'partitioned tables', migration: :gitlab_ci do
    let(:test_class) do
      Class.new do
        include MigrationsHelpers
        include Gitlab::BackgroundMigration::SpecHelpers::V1::TableHelpers

        def self.metadata
          { migration: :gitlab_ci }
        end
      end
    end

    context 'with CI partitioned table configuration' do
      before do
        test_class.configure_table :p_ci_builds, partitioned: true, database: :ci
      end

      it 'creates a partitioned table helper' do
        builds_table = instance.p_ci_builds

        expect(builds_table).to be_a(Class)
        expect(builds_table.table_name).to eq('p_ci_builds')
      end
    end
  end

  describe 'integration with existing specs' do
    it 'works alongside manual table definitions' do
      manual_table = instance.table(:namespaces)
      dynamic_table = instance.users

      # Both should work, though they create separate instances
      expect(manual_table.table_name).to eq('namespaces')
      expect(dynamic_table.table_name).to eq('users')
    end
  end
end
