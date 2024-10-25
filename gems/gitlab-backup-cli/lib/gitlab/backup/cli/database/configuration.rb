# frozen_string_literal: true

require 'active_record'

module Gitlab
  module Backup
    module Cli
      module Database
        class Configuration
          attr_reader :connection_name, :db_wrapper

          def initialize(connection_name, db_wrapper)
            @connection_name = connection_name
            @db_wrapper = db_wrapper
          end

          # TODO read config from yaml/context based on connection_name
          def activerecord_database_config
            @activerecord_database_config ||= activerecord_database_config
             {
              :adapter=>"postgresql",
              :encoding=>"unicode",
              :database=>"gitlabhq_development",
              :host=>"/Users/aakritigupta/Development/gdk/postgresql",
              :port=>5432,
              :pool=>10,
              :gssencmode=>"disable",
              :prepared_statements=>false,
              :variables=>{"statement_timeout"=>"120s"}
            }
          end
        end
      end
    end
  end
end
