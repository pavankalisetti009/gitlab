# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        # This class represents a dependency manager config file. It contains
        # logic to parse, extract, and process libraries from the file content.
        #
        # To support a new config file type/language:
        # 1. Create a new child class that inherits from this Base. The file name should be in
        #    the format: `<lang>_<dependency_manager_name>(_<additional_file_identifier>)`
        #    The additional file identifier should be "lock" when applicable.
        # 2. Add the new class to `ConfigFiles::Constants::CONFIG_FILE_CLASSES` and update
        #    the corresponding documentation (see comments in ConfigFiles::Constants.)
        #
        class Base
          EXPECTED_LIB_VERSION_TYPES = [String, Integer, Float, NilClass].freeze

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

          # Set to `true` if the dependency manager supports more than one config file
          def self.supports_multiple_files?
            false
          end

          def self.matching_paths(paths)
            supports_multiple_files? ? paths.select { |p| matches?(p) } : Array.wrap(paths.find { |p| matches?(p) })
          end

          def initialize(blob)
            @blob = blob
            @content = sanitize_content(blob.data)
            @path = blob.path
            @errors = []
          end

          def parse!
            return error('file empty') if content.blank?

            @libs = process_libs(extract_libs)

            # Default error message if there are no other errors
            error('unexpected format or dependencies not present') if libs.blank? && errors.empty?
          rescue ParsingError => e
            error(e)
          end

          # This hash matches the current XrayReport payload schema
          def payload
            return unless valid?

            {
              libs: formatted_libs,
              file_path: path
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

          def process_libs(libs)
            Array.wrap(libs).each do |lib|
              raise ParsingError, "unexpected dependency name type `#{lib.name.class}`" unless lib.name.is_a?(String)
              raise ParsingError, 'dependency name is blank' if lib.name.blank?

              unless lib.version.class.in?(EXPECTED_LIB_VERSION_TYPES)
                raise ParsingError, "unexpected dependency version type `#{lib.version.class}`"
              end

              lib.name = lib.name.strip
              lib.version = lib.version.to_s.strip
            end
          end

          def sanitize_content(content)
            content
              .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
              .delete("\u0000") # NULL byte is not permitted in JSON nor in PostgreSQL text-based columns
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

          # dig() throws a generic error in certain cases, e.g. when accessing an array with
          # a string key or calling it on an integer or nil. This method wraps dig() so that
          # we can capture these exceptions and re-raise them with a specific error message.
          def dig_in(obj, *keys)
            obj.dig(*keys)
          rescue NoMethodError, TypeError
            raise ParsingError, 'encountered unexpected node'
          end
        end
      end
    end
  end
end
