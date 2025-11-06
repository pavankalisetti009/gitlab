# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    module SpecHelpers
      module V1
        # Provides lazily evaluated and memoized table helpers for batched background migration specs.
        #
        # This module eliminates the need to manually define `let!` blocks for table helpers in every
        # migration spec. Instead, tables are automatically instantiated on first access and memoized
        # for subsequent use.
        #
        # @example Basic usage
        #   RSpec.describe Gitlab::BackgroundMigration::BackfillProjectId do
        #     include Gitlab::BackgroundMigration::SpecHelpers::V1::TableHelpers
        #
        #     it 'backfills project_id' do
        #       project = projects.create!(name: 'test')
        #       issue = issues.create!(project_id: project.id)
        #     end
        #   end
        #
        # @example With custom primary key
        #   RSpec.describe Gitlab::BackgroundMigration::SomeMigration do
        #     include Gitlab::BackgroundMigration::SpecHelpers::V1::TableHelpers
        #
        #     configure_table :custom_table, primary_key: :custom_id
        #
        #     it 'works' do
        #       custom_table.create!(custom_id: 1, name: 'test')
        #     end
        #   end
        #
        # @example With partitioned tables
        #   RSpec.describe Gitlab::BackgroundMigration::SomeMigration, migration: :gitlab_ci do
        #     include Gitlab::BackgroundMigration::SpecHelpers::V1::TableHelpers
        #
        #     configure_table :p_ci_builds, partitioned: true, by: :partition_id
        #
        #     it 'works' do
        #       p_ci_builds.create!(partition_id: 100, project_id: 1)
        #     end
        #   end
        module TableHelpers
          extend ActiveSupport::Concern

          included do
            # Store table configurations at the class level
            class_attribute :_table_configurations, default: {}
          end

          class_methods do
            # Configure a table with custom options
            #
            # @param table_name [Symbol] The name of the table
            # @param primary_key [Symbol, nil] Custom primary key column name
            # @param database [Symbol, nil] Database to use (:main, :ci, etc.)
            # @param partitioned [Boolean] Whether the table is partitioned
            # @param by [Symbol] Partition column (for partitioned tables)
            # @param strategy [Symbol] Partitioning strategy
            # @param partitioning_options [Hash] Additional partitioning options
            #
            # @example
            #   configure_table :users, primary_key: :user_id
            #   configure_table :p_ci_builds, partitioned: true, database: :ci
            def configure_table(
              table_name,
              primary_key: nil,
              database: nil,
              partitioned: false,
              by: :created_at,
              strategy: nil,
              **partitioning_options
            )
              self._table_configurations = _table_configurations.merge(
                table_name.to_sym => {
                  primary_key: primary_key,
                  database: database,
                  partitioned: partitioned,
                  by: by,
                  strategy: strategy,
                  partitioning_options: partitioning_options
                }
              )
            end
          end

          # Provides dynamic table access with lazy evaluation and memoization
          #
          # When a method is called that doesn't exist, this checks if it's a table name.
          # If so, it creates and memoizes a table helper for that table.
          #
          # @param method_name [Symbol] The method being called (table name)
          # @param args [Array] Method arguments (should be empty for table access)
          # @return [Class] An ActiveRecord model class for the table
          def method_missing(method_name, *args, &block)
            return super unless args.empty? && block.nil?

            # Check if this is a table access
            table_name = method_name.to_sym

            # Return memoized table if already created
            ivar_name = :"@#{table_name}"
            return instance_variable_get(ivar_name) if instance_variable_defined?(ivar_name)

            # Create and memoize the table helper
            table_helper = create_table_helper(table_name)
            instance_variable_set(ivar_name, table_helper)
            table_helper
          rescue ActiveRecord::StatementInvalid, NameError => e
            # Re-raise as NoMethodError to maintain expected behavior
            raise NoMethodError, "undefined method `#{method_name}' - #{e.message}"
          end

          # Indicates which methods will be handled by method_missing
          #
          # @return [Boolean] True if the method will be handled
          def respond_to_missing?(*)
            # We can't know all possible table names ahead of time,
            # so we'll let method_missing handle it and rescue if it fails
            true
          end

          private

          # Creates a table helper using the MigrationsHelpers#table method
          #
          # @param table_name [Symbol] The name of the table
          # @return [Class] An ActiveRecord model class for the table
          def create_table_helper(table_name)
            config = self.class._table_configurations[table_name] || {}

            if config[:partitioned]
              create_partitioned_table_helper(table_name, config)
            else
              create_regular_table_helper(table_name, config)
            end
          end

          # Creates a regular (non-partitioned) table helper
          #
          # @param table_name [Symbol] The name of the table
          # @param config [Hash] Table configuration options
          # @return [Class] An ActiveRecord model class for the table
          def create_regular_table_helper(table_name, config)
            # Use the table helper from MigrationsHelpers
            # This method should be available from the spec context
            table(
              table_name,
              database: config[:database],
              primary_key: config[:primary_key]
            )
          end

          # Creates a partitioned table helper
          #
          # @param table_name [Symbol] The name of the table
          # @param config [Hash] Table configuration options
          # @return [Class] An ActiveRecord model class for the table
          def create_partitioned_table_helper(table_name, config)
            # Auto-detect database from gitlab_schema if not explicitly configured
            database = config[:database] || detect_database_for_table(table_name)

            # Determine partitioning strategy
            strategy = config[:strategy]

            # For CI tables, use ci_partitioned_table if no custom strategy
            if database == :ci && strategy.nil?
              ci_partitioned_table(table_name)
            else
              partitioning_opts = config[:partitioning_options] || {}
              partitioning_opts[:strategy] = strategy if strategy

              partitioned_table(
                table_name,
                database: database,
                by: config[:by],
                **partitioning_opts
              )
            end
          end

          # Detects the appropriate database for a table based on its gitlab_schema
          #
          # This method looks up the table's gitlab_schema from the database dictionary
          # (db/docs/*.yml files) and maps it to the correct database connection using
          # the schema-to-database mappings defined in db/database_connections/*.yml
          #
          # @param table_name [Symbol] The name of the table
          # @return [Symbol, nil] The database name (:main, :ci, :sec) or nil if not found
          #
          # @example
          #   detect_database_for_table(:users)      # => :main (gitlab_main_user schema)
          #   detect_database_for_table(:ci_builds)  # => :ci (gitlab_ci schema)
          def detect_database_for_table(table_name)
            # Get the gitlab_schema for this table from db/docs/*.yml
            gitlab_schema = Gitlab::Database::GitlabSchema.table_schema(table_name)
            return unless gitlab_schema

            # Find which database connection serves this schema
            # schemas_to_base_models returns:
            # { gitlab_main_user: [ActiveRecord::Base], gitlab_ci: [Ci::ApplicationRecord] }
            base_models = Gitlab::Database.schemas_to_base_models[gitlab_schema]
            return if base_models.blank?

            # Map the base model back to database name (:main, :ci, :sec)
            Gitlab::Database.all_database_connections.find do |_db_name, db_info|
              base_models.include?(db_info.connection_class)
            end&.first
          end
        end
      end
    end
  end
end
