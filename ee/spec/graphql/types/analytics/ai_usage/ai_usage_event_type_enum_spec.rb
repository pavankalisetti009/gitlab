# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiUsage::AiUsageEventTypeEnum, feature_category: :value_stream_management do
  it 'includes a value for each usage event type' do
    expect(described_class.values).to match(
      'CODE_SUGGESTIONS_REQUESTED' => have_attributes(value: 'code_suggestions_requested'),
      'CODE_SUGGESTION_ACCEPTED_IN_IDE' => have_attributes(value: 'code_suggestion_accepted_in_ide'),
      'CODE_SUGGESTION_REJECTED_IN_IDE' => have_attributes(value: 'code_suggestion_rejected_in_ide'),
      'CODE_SUGGESTION_DIRECT_ACCESS_TOKEN_REFRESH' => have_attributes(
        value: 'code_suggestion_direct_access_token_refresh'
      ),
      'CODE_SUGGESTION_SHOWN_IN_IDE' => have_attributes(value: 'code_suggestion_shown_in_ide'),
      'REQUEST_DUO_CHAT_RESPONSE' => have_attributes(value: 'request_duo_chat_response'),
      'TROUBLESHOOT_JOB' => have_attributes(value: 'troubleshoot_job'),
      'START_AGENT_PLATFORM_SESSION' => have_attributes(value: 'start_agent_platform_session'),
      'CREATE_AGENT_PLATFORM_SESSION' => have_attributes(value: 'create_agent_platform_session')
    )
  end
end
