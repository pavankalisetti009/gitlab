# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Services
        autoload :Database, 'gitlab/backup/cli/services/database'
        autoload :Databases, 'gitlab/backup/cli/services/databases'
      end
    end
  end
end
