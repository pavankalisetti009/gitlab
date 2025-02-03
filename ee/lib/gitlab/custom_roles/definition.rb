# frozen_string_literal: true

module Gitlab
  module CustomRoles
    class Definition
      include ::Gitlab::CustomRoles::Shared

      class << self
        attr_accessor :definitions

        def all
          standard.merge(admin)
        end

        def admin
          @admin_definitions ||= load_definitions(admin_path)
        end

        def standard
          @standard_definitions ||= load_definitions(standard_path)
        end

        def load_abilities!
          @standard_definitions = load_definitions(standard_path)
          @admin_definitions = load_definitions(admin_path)
        end

        private

        def standard_path
          Rails.root.join("ee/config/custom_abilities/*.yml")
        end

        def admin_path
          Rails.root.join("ee/config/custom_abilities/admin/*.yml")
        end

        def load_definitions(path)
          definitions = {}

          Dir.glob(path).each do |file|
            definition = load_from_file(file)

            name = definition[:name].to_sym
            definitions[name] = definition
          end

          definitions
        end

        def load_from_file(path)
          definition = File.read(path)
          definition = YAML.safe_load(definition)
          definition.deep_symbolize_keys
        end
      end
    end
  end
end
