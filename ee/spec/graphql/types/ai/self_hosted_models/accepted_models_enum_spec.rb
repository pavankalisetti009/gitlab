# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAcceptedSelfHostedModels'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiAcceptedSelfHostedModels') }

  it 'exposes all the curated LLMs for self-hosted feature' do
    expect(described_class.values.keys).to include(*%w[
      CODEGEMMA_2B
      CODEGEMMA
      CODEGEMMA_7B
      CODELLAMA_13B_CODE
      CODELLAMA
      CODESTRAL
      MISTRAL
      MIXTRAL_8X22B
      MIXTRAL
    ])
  end
end
