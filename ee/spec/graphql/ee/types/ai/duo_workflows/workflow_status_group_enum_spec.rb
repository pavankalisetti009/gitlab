# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DuoWorkflowStatusGroup'], feature_category: :agent_foundations do
  it 'has specific fields' do
    expect(described_class.values.keys).to match_array(%w[
      ACTIVE PAUSED AWAITING_INPUT COMPLETED FAILED CANCELED
    ])
  end
end
