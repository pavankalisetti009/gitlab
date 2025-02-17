# spec/lib/code_suggestions/prompts/code_generation/amazon_q_spec.rb
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::AmazonQ, feature_category: :code_suggestions do
  let(:file_name) { 'example.rb' }
  let(:content_above_cursor) { 'def hello' }
  let(:content_below_cursor) { 'end' }
  let(:current_file) do
    {
      'file_name' => file_name,
      'content_above_cursor' => content_above_cursor,
      'content_below_cursor' => content_below_cursor
    }.with_indifferent_access
  end

  let(:params) do
    {
      current_file: current_file,
      stream: true
    }
  end

  let(:code_generation_enhancer) { 'some_enhancer' }
  let_it_be(:current_user) { create(:user) }

  subject(:amazon_q) { described_class.new(params, current_user) }

  before do
    allow(amazon_q).to receive(:code_generation_enhancer).and_return(code_generation_enhancer)
  end

  describe 'constants' do
    it 'has the correct MODEL_PROVIDER' do
      expect(described_class::MODEL_PROVIDER).to eq('amazon_q')
    end
  end

  describe '#request_params' do
    let(:expected_params) do
      {
        prompt_components: [
          {
            type: described_class::PROMPT_COMPONENT_TYPE,
            payload: {
              file_name: file_name,
              content_above_cursor: content_above_cursor,
              content_below_cursor: content_below_cursor,
              language_identifier: 'Ruby',
              stream: true,
              model_provider: described_class::MODEL_PROVIDER,
              model_name: described_class::MODEL_PROVIDER,
              role_arn: 'arn:aws:iam::123456789012:role/example-role'
            }
          }
        ]
      }
    end

    it 'returns the correct request parameters structure' do
      role_arn = 'arn:aws:iam::123456789012:role/example-role'

      ::Ai::Setting.instance.update!(
        amazon_q_role_arn: role_arn
      )
      expect(amazon_q.request_params).to eq(expected_params)
    end

    context 'when stream parameter is not provided' do
      let(:params) { {} }

      it 'defaults stream to false' do
        expect(amazon_q.request_params[:prompt_components].first[:payload][:stream]).to be false
      end
    end

    context 'when stream parameter is explicitly set to false' do
      let(:params) { { stream: false } }

      it 'keeps stream as false' do
        expect(amazon_q.request_params[:prompt_components].first[:payload][:stream]).to be false
      end
    end
  end
end
