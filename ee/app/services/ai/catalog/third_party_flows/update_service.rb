# frozen_string_literal: true

module Ai
  module Catalog
    module ThirdPartyFlows
      class UpdateService < Items::BaseUpdateService
        extend Gitlab::Utils::Override

        private

        override :validate_item
        def validate_item
          return error('ThirdPartyFlow not found') unless item && item.third_party_flow?

          error('ThirdPartyFlow definition does not have a valid YAML syntax') unless valid_definition?
        end

        override :build_version_params
        def build_version_params(_latest_version)
          return {} unless definition_parsed.present?

          { definition: definition_parsed }
        end

        override :save_item
        def save_item
          item.save
        end

        override :latest_schema_version
        def latest_schema_version
          Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION
        end

        def valid_definition?
          definition_parsed
          true
        rescue Psych::SyntaxError
          false
        end

        strong_memoize_attr def definition_parsed
          return unless params[:definition].present?

          YAML.safe_load(params[:definition]).merge(yaml_definition: params[:definition])
        end
      end
    end
  end
end
