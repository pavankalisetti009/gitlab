# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        module Constants
          CONFIG_FILE_CLASSES = [
            ConfigFiles::GoModules,
            ConfigFiles::JavaMaven,
            ConfigFiles::RubyGemsLock
          ].freeze
        end
      end
    end
  end
end
