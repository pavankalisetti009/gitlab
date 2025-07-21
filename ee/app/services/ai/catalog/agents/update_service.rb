# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class UpdateService < Ai::Catalog::BaseService
        def initialize(project:, current_user:, params:)
          @agent = params[:agent]
          super
        end

        def execute
          return error_no_permissions(payload: agent) unless allowed?
          return error('Agent not found', payload: agent) unless valid_agent?

          agent_params = params.slice(:name, :description, :public)

          version_params = params.slice(:system_prompt, :tools, :user_prompt).stringify_keys
          version_params['tools']&.map!(&:id)

          agent.assign_attributes(agent_params)

          latest_version = agent.latest_version
          latest_version.definition = latest_version.definition.merge(version_params)
          latest_version.schema_version = Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION if latest_version.changed?

          # Changes to the agent record are also saved through latest_version
          return ServiceResponse.success(payload: agent) if latest_version.save

          error(latest_version.errors.full_messages, payload: agent)
        end

        private

        attr_reader :agent

        def valid_agent?
          agent && agent.agent?
        end
      end
    end
  end
end
