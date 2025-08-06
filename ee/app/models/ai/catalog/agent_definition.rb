# frozen_string_literal: true

module Ai
  module Catalog
    class AgentDefinition < BaseDefinition
      def tool_names
        Ai::Catalog::BuiltInTool.where(id: tool_ids).map(&:name)
      end

      private

      def tool_ids
        Array(version.def_tools)
      end
    end
  end
end
