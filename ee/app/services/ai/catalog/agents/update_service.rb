# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class UpdateService < Ai::Catalog::BaseService
        AGENT_ATTRIBUTES = %i[name description public].freeze
        DEFINITION_ATTRIBUTES = %i[system_prompt tools user_prompt].freeze

        def initialize(project:, current_user:, params:)
          @agent = params[:agent]
          super
        end

        def execute
          return error_no_permissions(payload: payload) unless allowed?
          return error('Agent not found', payload: payload) unless valid_agent?

          agent_params = params.slice(*AGENT_ATTRIBUTES)
          agent.assign_attributes(agent_params)

          version_to_update = prepare_version_to_update

          # Changes to the agent record are also saved through version_to_update
          if version_to_update.save
            track_ai_item_events('update_ai_catalog_item', agent.item_type)
            return ServiceResponse.success(payload: payload)
          end

          error(version_to_update.errors.full_messages, payload: payload)
        end

        private

        attr_reader :agent

        def valid_agent?
          agent && agent.agent?
        end

        def payload
          { item: agent }
        end

        def prepare_version_to_update
          version_to_update = determine_version_to_update

          # A change to a version's definition will always cause its definition to match
          # the latest schema version, so ensure that it is set to the latest.
          if version_to_update.definition_changed?
            version_to_update.schema_version = Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION
          end

          version_to_update.release_date ||= Time.zone.now if params[:release] == true
          version_to_update
        end

        def determine_version_to_update
          latest_version = agent.latest_version
          version_params = build_version_params(latest_version)
          latest_version.assign_attributes(version_params)

          return latest_version unless latest_version.changed?
          return latest_version unless should_create_new_version?(latest_version)

          build_new_version(latest_version, version_params)
        end

        def build_version_params(latest_version)
          definition_params = params.slice(*DEFINITION_ATTRIBUTES).stringify_keys
          return {} if definition_params.empty?

          definition_params['tools']&.map!(&:id)

          {
            definition: latest_version.definition.merge(definition_params)
          }
        end

        def should_create_new_version?(version)
          version.released? && version.enforce_readonly_versions?
        end

        def build_new_version(latest_version, version_params)
          new_version_params = version_params.merge(
            version: calculate_next_version(latest_version)
          )

          agent.versions.build(new_version_params)
        end

        def calculate_next_version(latest_version)
          # TODO: Support params[:version_bump] parameter.
          # For now, always make a major version bump.
          latest_version.version_bump(Ai::Catalog::ItemVersion::VERSION_BUMP_MAJOR)
        end
      end
    end
  end
end
