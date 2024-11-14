# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Database
        autoload :Configuration, 'gitlab/backup/cli/database/configuration'
        autoload :Connection, 'gitlab/backup/cli/database/connection'
        autoload :Postgres, 'gitlab/backup/cli/database/postgres'
      end
    end
  end
end
