# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        module Constants
          # When adding a new class to this list:
          # 1. Order by language (alaphabetically), then by precedence. Lock files
          #    should appear first before their non-lock file counterparts.
          # 2. Update doc/user/project/repository/code_suggestions/repository_xray.md
          #    #supported-languages-and-package-managers.
          #
          # This ordering affects the result of
          # ConfigFileParser#find_config_file_paths_with_class.
          #
          CONFIG_FILE_CLASSES = [
            ConfigFiles::CppConanPy,
            ConfigFiles::CppConanTxt,
            ConfigFiles::CppVcpkg,
            ConfigFiles::CsharpNuget,
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
