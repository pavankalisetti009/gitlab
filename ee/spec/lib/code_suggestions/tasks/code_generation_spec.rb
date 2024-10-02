# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::CodeGeneration, feature_category: :code_suggestions do
  let(:prefix) { 'some prefix' }
  let(:suffix) { 'some suffix' }
  let(:instruction) { CodeSuggestions::Instruction.from_trigger_type('comment') }
  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => prefix,
      'content_below_cursor' => suffix
    }.with_indifferent_access
  end

  let(:expected_current_file) do
    { current_file: { file_name: 'test.py', content_above_cursor: 'fix', content_below_cursor: 'som' } }
  end

  context 'when using saas anthropic model' do
    before do
      allow(CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages)
        .to receive(:new).and_return(anthropic_messages_prompt)
      stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    end

    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [{ 'model_engine' => 'anthropic' }]
      }.with_indifferent_access
    end

    let(:params) do
      {
        code_generation_model_family: :anthropic,
        prefix: prefix,
        instruction: instruction,
        current_file: current_file,
        model_name: 'claude-3-5-sonnet-20240620'
      }
    end

    let(:anthropic_request_params) do
      {
        'prompt_components' => [
          {
            'type' => 'code_editor_generation',
            'payload' => {
              'file_name' => 'test.py',
              'content_above_cursor' => 'some prefix',
              'content_below_cursor' => 'some suffix',
              'language_identifier' => 'Python',
              'prompt_id' => 'code_suggestions/generations',
              'prompt_enhancer' => {
                'examples_array' => [
                  {
                    'example' => 'class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ',
                    'response' => "return self.visibility == 'PUBLIC'",
                    'trigger_type' => 'comment'
                  },
                  {
                    'example' => "# get the current user's name from the session data\\n{{cursor}}",
                    'response' => "username = session['username']\\nreturn username",
                    'trigger_type' => 'comment'
                  }
                ],
                'trimmed_prefix' => 'some prefix',
                'trimmed_suffix' => 'some suffix',
                'related_files' => '',
                'related_snippets' => '',
                'libraries' => '',
                'user_instruction' => 'Generate the best possible code based on instructions.'
              }
            }
          }
        ]
      }
    end

    let(:anthropic_messages_prompt) do
      instance_double(
        CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages,
        request_params: anthropic_request_params
      )
    end

    subject(:task) { described_class.new(params: params, unsafe_passthrough_params: unsafe_params) }

    it 'calls code creation Anthropic' do
      task.body
      expect(CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages)
        .to have_received(:new).with(params)
    end

    it_behaves_like 'code suggestion task' do
      let(:endpoint_path) { 'v3/code/completions' }
      let(:expected_body) do
        {
          'current_file' => {
            'content_above_cursor' => 'fix',
            'content_below_cursor' => 'som',
            'file_name' => 'test.py'
          },
          'prompt_components' => [
            {
              'payload' => {
                'content_above_cursor' => 'some prefix',
                'content_below_cursor' => 'some suffix',
                'file_name' => 'test.py',
                'language_identifier' => 'Python',
                'prompt_enhancer' => {
                  'examples_array' => [
                    {
                      'example' => 'class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ',
                      'response' => "return self.visibility == 'PUBLIC'",
                      'trigger_type' => 'comment'
                    },
                    {
                      'example' => "# get the current user's name from the session data\\n{{cursor}}",
                      'response' => "username = session['username']\\nreturn username",
                      'trigger_type' => 'comment'
                    }
                  ],
                  'trimmed_prefix' => 'some prefix',
                  'trimmed_suffix' => 'some suffix',
                  'related_files' => '',
                  'related_snippets' => '',
                  'libraries' => '',
                  'user_instruction' => 'Generate the best possible code based on instructions.'
                },
                'prompt_id' => 'code_suggestions/generations'
              },
              'type' => 'code_editor_generation'
            }
          ],
          'telemetry' => [{ 'model_engine' => 'anthropic' }]
        }
      end

      let(:expected_feature_name) { :code_suggestions }
    end

    context 'when FF `anthropic_code_gen_aigw_migration` is disabled' do
      let(:anthropic_request_params) { { prompt_version: 2, prompt: 'Anthropic prompt' } }
      let(:anthropic_messages_prompt) do
        instance_double(
          CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages,
          request_params: anthropic_request_params
        )
      end

      before do
        allow(CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages)
          .to receive(:new).and_return(anthropic_messages_prompt)
        stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
        stub_feature_flags(anthropic_code_gen_aigw_migration: false)
      end

      it 'calls code creation Anthropic' do
        task.body
        expect(CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages)
          .to have_received(:new).with(params)
      end

      it_behaves_like 'code suggestion task' do
        let(:endpoint_path) { 'v2/code/generations' }
        let(:expected_body) do
          {
            "current_file" => {
              "file_name" => "test.py",
              "content_above_cursor" => "fix",
              "content_below_cursor" => "som"
            },
            "telemetry" => [{ "model_engine" => "anthropic" }],
            "prompt_version" => 2,
            "prompt" => "Anthropic prompt"
          }
        end

        let(:expected_feature_name) { :code_suggestions }
      end
    end
  end

  context 'when using self hosted model' do
    let_it_be(:feature_setting) { create(:ai_feature_setting) }

    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [],
        'stream' => false
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file,
        generation_type: 'empty_function'
      }
    end

    subject(:task) do
      described_class.new(params: params, unsafe_passthrough_params: unsafe_params)
    end

    it_behaves_like 'code suggestion task' do
      let(:endpoint_path) { 'v2/code/generations' }
      let(:expected_body) do
        {
          "telemetry" => [],
          "prompt_id" => "code_suggestions/generations",
          "current_file" => {
            "content_above_cursor" => "some prefix",
            "content_below_cursor" => "some suffix",
            "file_name" => "test.py"
          },
          "model_api_key" => "token",
          "model_endpoint" => "http://localhost:11434/v1",
          "model_identifier" => "provider/some-model",
          "model_name" => "mistral",
          "model_provider" => "litellm",
          "prompt" => "",
          "prompt_version" => 2,
          "stream" => false
        }
      end

      let(:expected_feature_name) { :self_hosted_models }
    end
  end
end
