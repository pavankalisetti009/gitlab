# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        # This class represents a dependency manager config file. It contains logic
        # to parse and extract libraries from the file content. To support a new
        # config file type/language, create a new class that inherits from this Base.
        # Then append the new class name to ConfigFiles::Constants::CONFIG_FILE_CLASSES.
        class Base
          include Gitlab::Utils::StrongMemoize

          # This value is supposed to indicate the version of Repository X-Ray we are using;
          # however, it's not applicable here so we just set it to a placeholder value.
          # It may be removed entirely in https://gitlab.com/gitlab-org/gitlab/-/issues/479185.
          SCANNER_VERSION = '0.0.0'

          ParsingError = Class.new(StandardError)

          Lib = Struct.new(:name, :version, keyword_init: true)

          def self.file_name_glob
            raise NotImplementedError
          end

          def self.lang_name
            raise NotImplementedError
          end

          def self.lang
            CodeSuggestions::ProgrammingLanguage::LANGUAGE_XRAY_NAMING[lang_name]
          end

          def self.matches?(path)
            File.fnmatch?("**/#{file_name_glob}", path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
          end

          def initialize(blob)
            @blob = blob
            @content = blob.data
            @path = blob.path
            @errors = []
          end

          def parse!
            return error('file empty') if content.blank?

            @libs = extract_libs
            sanitize_libs!

            # Default error message if there are no other errors
            error('format not recognized or dependencies not present') if libs.blank? && errors.empty?
          rescue ParsingError => e
            error(e)
          ensure
            track_error unless valid?
          end

          # This hash matches the current XrayReport payload schema
          def payload
            return unless valid?

            {
              libs: formatted_libs,
              checksum: checksum,
              fileName: path,
              scannerVersion: SCANNER_VERSION
            }
          end

          def valid?
            errors.empty?
          end

          def error_message
            return if valid?

            "Error(s) while parsing file `#{path}`: #{errors.join(', ')}"
          end

          private

          attr_reader :blob, :content, :path, :libs, :errors

          # To record an error, either use error() directly or raise ParsingError
          def extract_libs
            raise NotImplementedError
          end

          def sanitize_libs!
            @libs = Array.wrap(libs).filter_map do |lib|
              next if lib.name.blank?

              lib.name = lib.name.strip
              lib.version = lib.version&.strip
              lib
            end
          rescue NoMethodError
            # Raised when `.strip` is called on a non-string
            raise ParsingError, 'dependency name or version is an invalid type'
          end

          def formatted_libs
            libs.map do |lib|
              lib_name = lib.version.presence ? "#{lib.name} (#{lib.version})" : lib.name

              { name: lib_name }
            end
          end

          def error(message)
            @errors << message
          end

          def checksum
            Digest::SHA256.hexdigest(content)
          end
          strong_memoize_attr :checksum

          # dig() throws a generic error in certain cases, e.g. when accessing an array with
          # a string key or calling it on an integer or nil. This method wraps dig() so that
          # we can capture these exceptions and re-raise them with a specific error message.
          def dig_in(obj, *keys)
            obj.dig(*keys)
          rescue NoMethodError, TypeError
            raise ParsingError, 'encountered invalid node'
          end

          def track_error
            message = "#{self.class.name.demodulize} parsing error(s): #{errors.join(', ')}. If this error " \
              "occurs in multiple projects, we may need to update the parsing logic in `#{self.class.name}`."

            Gitlab::ErrorTracking.track_exception(
              ParsingError.new(message),
              class: self.class.name,
              file_path: path,
              project_id: blob.project.id
            )
          end
        end
      end
    end
  end
end
