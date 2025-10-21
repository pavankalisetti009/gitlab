# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AiFlowTriggersHelper, feature_category: :duo_agent_platform do
  describe '#ai_flow_triggers_event_type_options' do
    it 'returns formatted options for all event types' do
      stub_const('::Ai::FlowTrigger::EVENT_TYPES', {
        mention: 0,
        comment: 1,
        issue_created: 2
      })

      expected_options = [
        { text: 'Mention', value: 0 },
        { text: 'Comment', value: 1 },
        { text: 'Issue created', value: 2 }
      ].to_json

      expect(helper.ai_flow_triggers_event_type_options).to eq(expected_options)
    end
  end
end
