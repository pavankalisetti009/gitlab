# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Database
        autoload :Configuration, 'gitlab/backup/cli/database/configuration'
        autoload :Connection, 'gitlab/backup/cli/database/connection'
        autoload :EachDatabase, 'gitlab/backup/cli/database/each_database'
        autoload :Postgres, 'gitlab/backup/cli/database/postgres'
        autoload :Wrapper, 'gitlab/backup/cli/database/wrapper'
      end
    end
  end
end
