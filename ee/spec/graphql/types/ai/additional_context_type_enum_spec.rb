# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAdditionalContextType'], feature_category: :duo_chat do
  it 'exposes all additional context types' do
    expect(described_class.values.keys).to match_array(%w[FILE SNIPPET])
  end
end
