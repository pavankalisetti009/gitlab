# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class DestroyService < Ai::Catalog::BaseService
        def initialize(project:, current_user:, params:)
          @agent = params[:agent]
          super
        end

        def execute
          return error_no_permissions unless allowed?
          return error_no_agent unless valid_agent?

          delete_agent ? success : error_response
        end

        private

        attr_reader :agent

        def valid_agent?
          agent && agent.agent?
        end

        def success
          ServiceResponse.success
        end

        def error_response
          error(agent.errors.full_messages)
        end

        def error_no_agent
          error('Agent not found')
        end

        def delete_agent
          return agent.soft_delete if agent.consumers.any?

          agent.destroy
        end
      end
    end
  end
end
