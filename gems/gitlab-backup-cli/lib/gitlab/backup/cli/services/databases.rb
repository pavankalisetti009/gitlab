# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Services
        class Databases
          include Enumerable
          attr_reader :context

          def initialize(context)
            @context = context
          end

          def each
            return enum_for(__method__) unless block_given?

            entries.each do |item|
              yield(item)
            end
          end

          def entries
            return @entries if defined?(@entries)

            @entries = database_configurations.map do |config|
              Database.new(config)
            end
          end

          private

          def database_configurations
            return @database_configurations if defined?(@database_configurations)

            config_yaml = YAML.load_file(context.database_config_file_path, aliases: true)
            ActiveRecord::Base.configurations = config_yaml

            @database_configurations = ActiveRecord::Base.configurations
                                                         .configs_for(env_name: context.env, include_hidden: false)
          rescue Errno::ENOENT
            raise Gitlab::Backup::Cli::Errors::DatabaseConfigMissingError, context.database_config_file_path
          end
        end
      end
    end
  end
end
