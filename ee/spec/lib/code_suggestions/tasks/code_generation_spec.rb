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
        "prompt_components" => [
          {
            "type" => "code_editor_generation",
            "payload" => {
              "file_name" => "test.py",
              "content_above_cursor" => "some prefix",
              "content_below_cursor" => "some suffix",
              "language_identifier" => "Python",
              "prompt_id" => "code_suggestions/generations",
              "prompt_enhancer" => {
                "examples_array" => [
                  {
                    "example" => "class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ",
                    "response" => "return self.visibility == 'PUBLIC'",
                    "trigger_type" => "comment"
                  },
                  {
                    "example" => "# get the current user's name from the session data\\n{{cursor}}",
                    "response" => "username = session['username']\\nreturn username",
                    "trigger_type" => "comment"
                  }
                ],
                "trimmed_prefix" => "some prefix",
                "trimmed_suffix" => "some suffix"
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
          "current_file" => {
            "content_above_cursor" => "fix",
            "content_below_cursor" => "som",
            "file_name" => "test.py"
          },
          "prompt_components" => [
            {
              "payload" => {
                "content_above_cursor" => "some prefix",
                "content_below_cursor" => "some suffix",
                "file_name" => "test.py",
                "language_identifier" => "Python",
                "prompt_enhancer" => {
                  "examples_array" => [
                    {
                      "example" => "class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ",
                      "response" => "return self.visibility == 'PUBLIC'",
                      "trigger_type" => "comment"
                    },
                    {
                      "example" => "# get the current user's name from the session data\\n{{cursor}}",
                      "response" => "username = session['username']\\nreturn username",
                      "trigger_type" => "comment"
                    }
                  ],
                  "trimmed_prefix" => "some prefix",
                  "trimmed_suffix" => "some suffix"
                },
                "prompt_id" => "code_suggestions/generations"
              },
              "type" => "code_editor_generation"
            }
          ],
          "telemetry" => [{ "model_engine" => "anthropic" }]
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

  context 'when ai_custom_models_prompts_migration feature flag is disabled' do
    before do
      stub_feature_flags(ai_custom_models_prompts_migration: false)
    end

    context 'when using self hosted mistral, mixtral, codegemma, codestral model' do
      let_it_be(:code_generations_feature_setting) { create(:ai_feature_setting, feature: :code_generations) }

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

      let(:mistral_request_params) { { prompt_version: 3, prompt: 'Mistral prompt' } }
      let(:mistral_messages_prompt) do
        instance_double(CodeSuggestions::Prompts::CodeGeneration::MistralMessages,
          request_params: mistral_request_params)
      end

      subject(:task) do
        described_class.new(params: params, unsafe_passthrough_params: unsafe_params)
      end

      before do
        allow(CodeSuggestions::Prompts::CodeGeneration::MistralMessages)
          .to receive(:new).and_return(mistral_messages_prompt)

        stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
      end

      it 'calls Mistral' do
        task.body
        expect(CodeSuggestions::Prompts::CodeGeneration::MistralMessages)
          .to have_received(:new).with(feature_setting: code_generations_feature_setting, params: params)
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
            "telemetry" => [],
            "stream" => false,
            "prompt_version" => 3,
            "prompt" => "Mistral prompt"
          }
        end

        let(:expected_feature_name) { :self_hosted_models }
      end
    end

    context 'when using self hosted codellama model' do
      let_it_be(:self_hosted_model) { create(:ai_self_hosted_model, model: 'codellama', name: "whatever") }
      let_it_be(:code_generations_feature_setting) do
        create(:ai_feature_setting, feature: :code_generations, self_hosted_model: self_hosted_model)
      end

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

      let(:prompt_content) do
        "[INST]<<SYS>> You are a tremendously accurate and skilled code generation agent. " \
          "We want to generate new Python code inside the file 'test.py'. Your task is to provide valid code without " \
          "any additional explanations, comments, or feedback. " \
          "<</SYS>>\n\nsome prefix\n[SUGGESTION]\nsome suffix\n\nThe new code you will generate will start at the " \
          "position of the cursor, " \
          "which is currently indicated by the [SUGGESTION] tag.\nThe comment directly " \
          "before the cursor position is the instruction, " \
          "all other comments are not instructions.\n\nWhen generating the new code, please ensure the following:\n" \
          "1. It is valid Python code.\n" \
          "2. It matches the existing code's variable, parameter, and function names.\n" \
          "3. The code fulfills the instructions.\n" \
          "4. Do not add any comments, including instructions.\n" \
          "5. Return the code result without any extra explanation or examples.\n\n" \
          "If you are not able to generate code based on the given instructions, return an empty result.\n\n[/INST]"
      end

      subject(:task) do
        described_class.new(params: params, unsafe_passthrough_params: unsafe_params)
      end

      before do
        stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
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
            "telemetry" => [],
            "stream" => false,
            "prompt_version" => 3,
            "model_endpoint" => "http://localhost:11434/v1",
            "model_name" => "codellama",
            "model_provider" => "litellm",
            "model_api_key" => "token",
            "prompt" => [
              {
                "content" => prompt_content,
                "role" => "user"
              }
            ]
          }
        end

        let(:expected_feature_name) { :self_hosted_models }
      end
    end

    context 'when model name is unknown' do
      before do
        allow(Ai::FeatureSetting).to receive(:find_by_feature).with(:code_generations).and_return(ai_feature_setting)
        allow(ai_feature_setting).to receive_message_chain(:self_hosted_model, :model, :to_sym).and_return("unknown")
      end

      let(:ai_feature_setting) do
        instance_double(Ai::FeatureSetting, self_hosted?: true)
      end

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

      it 'raises an error' do
        expect { task.body }.to raise_error("Unknown model: unknown")
      end
    end
  end
end
