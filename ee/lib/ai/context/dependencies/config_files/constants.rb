# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        module Constants
          # List classes by language (alphabetically), then by precedence. Lock files
          # should always appear first before non-lock files. This ordering affects
          # the result of ConfigFileParser#find_config_file_paths_with_class.
          CONFIG_FILE_CLASSES = [
            ConfigFiles::CppConanPy,
            ConfigFiles::CppConanTxt,
            ConfigFiles::GoModules,
            ConfigFiles::JavaGradle,
            ConfigFiles::JavaMaven,
            ConfigFiles::KotlinGradle,
            ConfigFiles::RubyGemsLock
          ].freeze
        end
      end
    end
  end
end
