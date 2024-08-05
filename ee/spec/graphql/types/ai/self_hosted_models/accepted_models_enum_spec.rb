# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAcceptedSelfHostedModels'], feature_category: :custom_models do
  it { expect(described_class.graphql_name).to eq('AiAcceptedSelfHostedModels') }

  it 'exposes all compatible models available in ::Ai::SelfHostedModel' do
    expect(
      ::Ai::SelfHostedModel.models.keys.map do |model|
        # strip colon as Graphql does not allow it with enum fields
        model.delete(':').upcase
      end
    ).to eq(described_class.values.keys)
  end
end
