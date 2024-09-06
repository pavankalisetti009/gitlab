# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage, feature_category: :"self-hosted_models" do
  let_it_be(:ai_self_hosted_model) { create(:ai_self_hosted_model, model: :codestral, name: 'whatever', endpoint: 'http://example.com/endpoint') }
  let_it_be(:ai_feature_setting) do
    create(
      :ai_feature_setting,
      feature: :code_completions,
      self_hosted_model: ai_self_hosted_model
    )
  end

  let(:dummy_class) do
    Class.new(described_class) do
      def prompt
        'dummy prompt'
      end
    end
  end

  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => 'some prefix',
      'content_below_cursor' => 'some suffix'
    }.with_indifferent_access
  end

  let(:params) do
    {
      current_file: current_file
    }
  end

  let(:dummy_message) do
    dummy_class.new(feature_setting: ::Ai::FeatureSetting.find_by_feature(:code_completions), params: params)
  end

  describe '#request_params' do
    it 'returns the correct request params' do
      expected_params = {
        model_provider: 'litellm',
        prompt_version: 2,
        prompt: 'dummy prompt',
        model_endpoint: 'http://example.com/endpoint',
        model_name: 'codestral',
        model_api_key: "token"
      }

      expect(dummy_message.request_params).to eq(expected_params)
    end
  end

  describe '#prompt' do
    it 'raises NotImplementedError for the abstract class' do
      expect(described_class.new(
        feature_setting: ::Ai::FeatureSetting.find_by_feature(:code_completions),
        params: params
      ).prompt).to be_nil
    end
  end
end
