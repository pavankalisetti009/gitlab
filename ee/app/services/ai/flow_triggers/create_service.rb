# frozen_string_literal: true

module Ai
  module FlowTriggers
    class CreateService < BaseService
      def initialize(project:, current_user:)
        @project = project
        @current_user = current_user
      end

      def execute(params)
        if !new_external_agents_allowed? && creating_external_agent_trigger?(params)
          return disallow_new_external_agent_error
        end

        super do
          project.ai_flow_triggers.create(params)
        end
      end

      def creating_external_agent_trigger?(params)
        return true if params[:config_path].present?
        return false if params[:ai_catalog_item_consumer_id].nil?

        consumer = Ai::Catalog::ItemConsumer.find_by_id(params[:ai_catalog_item_consumer_id])

        return false if consumer.nil?

        consumer.item.third_party_flow?
      end
    end
  end
end
