# frozen_string_literal: true

module Projects
  module AiFlowTriggersHelper
    def ai_flow_triggers_event_type_options
      ::Ai::FlowTrigger::EVENT_TYPES.map do |key, value|
        { text: key.to_s.humanize, value: value }
      end.to_json
    end
  end
end
