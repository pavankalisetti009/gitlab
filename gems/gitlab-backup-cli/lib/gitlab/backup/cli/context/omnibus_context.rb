# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Context
        class OmnibusContext < SourceContext
          OMNIBUS_CONFIG_ENV = 'GITLAB_BACKUP_CLI_CONFIG_FILE'

          # Is the tool running in an Omnibus installation?
          #
          # @return [Boolean]
          def self.available?
            ENV.key?(OMNIBUS_CONFIG_ENV) && omnibus_config_filepath.exist?
          end

          # @return [Pathname|Nillable]
          def self.omnibus_config_filepath
            unless ENV.key?(OMNIBUS_CONFIG_ENV)
              raise ::Gitlab::Backup::Cli::Error, "#{OMNIBUS_CONFIG_ENV} is not defined"
            end

            Pathname(ENV.fetch(OMNIBUS_CONFIG_ENV))
          end
        end
      end
    end
  end
end
