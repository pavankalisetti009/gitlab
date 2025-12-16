# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiNamespaceSettings'], feature_category: :duo_chat do
  it 'has specific fields' do
    expected_fields = %w[duoWorkflowMcpEnabled promptInjectionProtectionLevel]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'duoWorkflowMcpEnabled field' do
    it 'returns a boolean' do
      field = described_class.fields['duoWorkflowMcpEnabled']
      expect(field.type).to be_a(GraphQL::Schema::NonNull)
      expect(field.type.of_type).to eq(GraphQL::Types::Boolean)
    end
  end

  describe 'promptInjectionProtectionLevel field' do
    it 'returns the PromptInjectionProtectionLevel enum' do
      field = described_class.fields['promptInjectionProtectionLevel']
      expect(field.type).to be_a(GraphQL::Schema::NonNull)
      expect(field.type.of_type).to eq(GitlabSchema.types['PromptInjectionProtectionLevel'])
    end
  end
end
