# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::FlowTriggerType, feature_category: :duo_agent_platform do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiFlowTriggerType')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      id
      description
      event_types
      config_path
      config_url
      project
      user
      ai_catalog_item_consumer
      created_at
      updated_at
    ]

    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class).to require_graphql_authorizations(:manage_ai_flow_triggers) }
end
