# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class UpdateService < Items::BaseUpdateService
        extend Gitlab::Utils::Override
        include FlowHelper
        include Concerns::YamlDefinitionParser

        private

        override :validate_item
        def validate_item
          return error('Flow not found') unless item && item.flow?

          yaml_syntax_error unless valid_yaml_definition?
        end

        override :build_version_params
        def build_version_params(_latest_version)
          parsed_definition_param
        end

        override :save_item
        def save_item
          item.save
        end

        override :latest_schema_version
        def latest_schema_version
          Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION
        end
      end
    end
  end
end
