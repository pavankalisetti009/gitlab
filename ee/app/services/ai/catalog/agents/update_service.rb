# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class UpdateService < Items::BaseUpdateService
        extend Gitlab::Utils::Override

        DEFINITION_ATTRIBUTES = %i[system_prompt tools user_prompt].freeze

        private

        override :validate_item
        def validate_item
          error('Agent not found') unless item && item.agent?
        end

        override :build_version_params
        def build_version_params(latest_version)
          definition_params = params.slice(*DEFINITION_ATTRIBUTES).stringify_keys
          return {} if definition_params.empty?

          definition_params['tools']&.map!(&:id)

          {
            definition: latest_version.definition.merge(definition_params)
          }
        end

        override :save_item
        def save_item
          item.save
        end

        override :latest_schema_version
        def latest_schema_version
          Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION
        end

        override :track_update_audit_event
        def track_update_audit_event
          send_audit_events('update_ai_catalog_agent', item, { old_definition: old_definition })
        end
      end
    end
  end
end
