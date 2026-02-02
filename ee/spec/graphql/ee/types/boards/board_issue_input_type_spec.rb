# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['BoardIssueInput'], feature_category: :portfolio_management do
  it 'has specific fields' do
    allowed_args = %w[epicId epicWildcardId includeSubepics iterationTitle iterationWildcardId weight
      healthStatusFilter status]

    expect(described_class.arguments.keys).to include(*allowed_args)
  end
end
