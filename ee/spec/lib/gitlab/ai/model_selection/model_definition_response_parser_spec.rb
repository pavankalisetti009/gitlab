# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser, feature_category: :"self-hosted_models" do
  include_context 'with fetch_model_definitions_example'

  let(:model_definitions_response) { fetch_model_definitions_example }

  subject(:parser) { described_class.new(model_definitions_response) }

  describe '#model_with_ref' do
    context 'when the ref exists' do
      it 'returns the model with the given ref' do
        expect(parser.model_with_ref('claude-sonnet')).to eq(
          {
            'name' => 'Claude Sonnet',
            'ref' => 'claude-sonnet',
            'model_provider' => 'Anthropic'
          }
        )
      end
    end

    context 'when the ref does not exist' do
      it 'returns nil' do
        expect(parser.model_with_ref('non-existent-model')).to be_nil
      end
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.model_with_ref(:duo_chat)).to be_nil
      end
    end
  end

  describe '#definition_for_feature' do
    context 'when the feature exists' do
      it 'returns the definition for the given feature' do
        expect(parser.definition_for_feature(:duo_chat)).to eq({
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet gpt-4],
          'beta_models' => []
        })
      end
    end

    context 'when the feature does not exist' do
      it 'returns nil' do
        expect(parser.definition_for_feature(:non_existent_feature)).to be_nil
      end
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.definition_for_feature(:duo_chat)).to be_nil
      end
    end
  end

  describe '#selectable_models_for_feature' do
    context 'when the feature exists' do
      it 'returns the selectable models for the given feature' do
        expect(parser.selectable_models_for_feature(:duo_chat)).to eq(%w[claude-sonnet gpt-4])
      end
    end

    context 'when the feature does not exist' do
      it 'returns an empty array' do
        expect(parser.selectable_models_for_feature(:non_existent_feature)).to eq([])
      end
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'returns an empty array' do
        expect(parser.selectable_models_for_feature(:duo_chat)).to eq([])
      end
    end
  end

  describe '#gitlab_models_by_ref' do
    it 'returns a hash of models indexed by their ref' do
      expect(parser.gitlab_models_by_ref).to eq(
        {
          'claude-sonnet' => {
            'name' => 'Claude Sonnet',
            'ref' => 'claude-sonnet',
            'model_provider' => 'Anthropic'
          },
          'gpt-4' => {
            'name' => 'GPT-4',
            'ref' => 'gpt-4',
            'model_provider' => 'OpenAI'
          },
          'claude-sonnet-3-7' => {
            'name' => 'Claude Sonnet 3.7',
            'ref' => 'claude-sonnet-3-7',
            'model_provider' => 'Anthropic'
          }
        }
      )
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.gitlab_models_by_ref).to be_nil
      end
    end

    context 'if definitions is empty' do
      let(:model_definitions_response) { {} }

      it 'is nil' do
        expect(parser.gitlab_models_by_ref).to be_nil
      end
    end
  end

  describe '#model_definition_per_feature' do
    it 'returns a hash of unit primitives indexed by feature setting' do
      expect(parser.model_definition_per_feature).to eq({
        'duo_chat' => {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet gpt-4],
          'beta_models' => []
        },
        'code_completions' => {
          'feature_setting' => 'code_completions',
          'default_model' => 'gpt-4',
          'selectable_models' => %w[gpt-4],
          'beta_models' => []
        },
        'review_merge_request' => {
          'feature_setting' => 'review_merge_request',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet claude-sonnet-3-7],
          'beta_models' => []
        }
      })
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.model_definition_per_feature).to be_nil
      end
    end

    context 'if definitions is empty' do
      let(:model_definitions_response) { {} }

      it 'is nil' do
        expect(parser.model_definition_per_feature).to be_nil
      end
    end
  end

  describe '#deprecated_models' do
    it 'returns a list of deprecated models' do
      expect(parser.deprecated_models).to eq([
        {
          'name' => 'Claude Sonnet 3.7',
          'identifier' => 'claude-sonnet-3-7',
          'provider' => 'Anthropic',
          'deprecation' => {
            'deprecation_date' => '2025-10-28',
            'removal_version' => '18.8'
          }
        }
      ])
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.deprecated_models).to be_nil
      end
    end

    context 'if definitions is empty' do
      let(:model_definitions_response) { {} }

      it 'is nil' do
        expect(parser.deprecated_models).to be_nil
      end
    end
  end
end
