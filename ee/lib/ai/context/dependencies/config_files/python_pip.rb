# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        class PythonPip < Base
          OPTION_REGEX = /^-/
          NAME_VERSION_REGEX = /(?<name>^[^!=><~]+)(?<version>[!=><~]+.*$)?/
          OTHER_SPECIFIERS_REGEX = /[@;]+.*$/ # Matches URL or other non-version specifiers at the end of line
          COMMENT_ONLY_REGEX = /^#/
          INLINE_COMMENT_REGEX = /\s+#.*$/

          def self.file_name_glob
            'requirements.txt'
          end

          def self.lang_name
            'Python'
          end

          private

          ### Example format:
          #
          # requests>=2.0,<3.0      # Version range
          # numpy==1.26.4           # Exact version match
          # fastapi-health!=0.3.0   # Exclusion
          #
          # # New supported formats
          # pytest >= 2.6.4 ; python_version < '3.8'
          # openpyxl == 3.1.2
          # urllib3 @ https://github.com/path/main.zip
          #
          # # Nested requirement files currently not supported
          # # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/491800
          # -r other_requirements.txt
          # # Other options
          # -i https://pypi.org/simple
          # --python-version 3
          #
          def extract_libs
            content.each_line.filter_map do |line|
              line.strip!
              next if line.blank? || Regexp.union(COMMENT_ONLY_REGEX, OPTION_REGEX).match?(line)

              parse_lib(line)
            end
          end

          def parse_lib(line)
            line.gsub!(Regexp.union(INLINE_COMMENT_REGEX, OTHER_SPECIFIERS_REGEX), '')
            match = NAME_VERSION_REGEX.match(line)

            Lib.new(name: match[:name], version: match[:version]) if match
          end
        end
      end
    end
  end
end
