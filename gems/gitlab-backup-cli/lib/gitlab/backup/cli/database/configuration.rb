# frozen_string_literal: true

require 'active_record'

module Gitlab
  module Backup
    module Cli
      module Database
        class Configuration
          # Connection name is the key used in `config/database.yml` for multi-database connection configuration
          #
          # @return [String]
          attr_reader :connection_name, :activerecord_variables

          # ActiveRecord base model that is configured to connect to the database identified by connection_name key
          #
          # @return [ActiveRecord::Base]
          attr_reader :source_model, :db_wrapper

          # Initializes configuration
          #
          # @param [String] connection_name the key from `database.yml` for multi-database connection configuration
          def initialize(connection_name, db_wrapper)
            @connection_name = connection_name
            @db_wrapper = db_wrapper
            @source_model = db_wrapper.database_base_models_with_gitlab_shared[connection_name] ||
              db_wrapper.database_base_models_with_gitlab_shared['main']
            @activerecord_database_config = ActiveRecord::Base.configurations.find_db_config(connection_name) ||
              ActiveRecord::Base.configurations.find_db_config('main')
          end

          # # Return the HashConfig for the database
          # #
          # # @return [ActiveRecord::DatabaseConfigurations::HashConfig]
          def activerecord_configuration
            ActiveRecord::DatabaseConfigurations::HashConfig.new(
              @activerecord_database_config&.env_name || db_wrapper.context.env,
              connection_name,
              activerecord_variables
            )
          end

          private

          # Return the database configuration from rails config/database.yml file
          # in the format expected by ActiveRecord::DatabaseConfigurations::HashConfig
          #
          # @return [Hash] configuration hash
          def original_activerecord_config
            @activerecord_database_config.configuration_hash.dup
          end
        end
      end
    end
  end
end
