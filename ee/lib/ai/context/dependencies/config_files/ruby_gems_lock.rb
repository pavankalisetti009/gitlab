# frozen_string_literal: true

module Ai
  module Context
    module Dependencies
      module ConfigFiles
        class RubyGemsLock < Base
          def self.file_name_glob
            'Gemfile.lock'
          end

          def self.lang_name
            'Ruby'
          end

          private

          ### Example format:
          #
          # GEM
          # remote: https://rubygems.org/
          # specs:
          #   bcrypt (3.1.20)
          #   logger (1.5.3)
          #
          def extract_libs
            parser = Bundler::LockfileParser.new(content)

            parser.specs.map do |spec|
              Lib.new(name: spec.name, version: spec.version.to_s)
            end
          end
        end
      end
    end
  end
end
