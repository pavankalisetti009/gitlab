# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::CodeCompletion, feature_category: :code_suggestions do
  let(:endpoint_path) { 'v2/code/completions' }

  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => 'some content_above_cursor',
      'content_below_cursor' => 'some content_below_cursor'
    }.with_indifferent_access
  end

  let(:expected_current_file) do
    { current_file: { file_name: 'test.py', content_above_cursor: 'sor', content_below_cursor: 'som' } }
  end

  let(:model_engine) { nil } # set in the relevant contexts

  let(:params) do
    {
      current_file: current_file
    }
  end

  let(:unsafe_params) do
    {
      'current_file' => current_file,
      'telemetry' => [{ 'model_engine' => model_engine }]
    }.with_indifferent_access
  end

  let(:current_user) { create(:user) }

  let(:task) do
    described_class.new(
      params: params,
      unsafe_passthrough_params: unsafe_params,
      current_user: current_user
    )
  end

  before do
    stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    stub_feature_flags(fireworks_qwen_code_completion: false)
    stub_feature_flags(incident_fail_over_completion_provider: false)
  end

  describe 'saas failover model' do
    before do
      stub_feature_flags(incident_fail_over_completion_provider: true)
    end

    let(:model_engine) { :anthropic }

    let(:anthropic_request_body) do
      {
        'model_name' => 'claude-3-5-sonnet-20240620',
        'model_provider' => 'anthropic',
        'current_file' => {
          'file_name' => 'test.py',
          'content_above_cursor' => 'sor',
          'content_below_cursor' => 'som'
        },
        'telemetry' => [{ 'model_engine' => 'anthropic' }],
        'prompt_version' => 3,
        'prompt' => [
          {
            "content" => "You are a code completion tool that performs Fill-in-the-middle. Your task is to " \
              "complete the Python code between the given prefix and suffix inside the file 'test.py'.\nYour " \
              "task is to provide valid code without any additional explanations, comments, or feedback." \
              "\n\nImportant:\n- You MUST NOT output any additional human text or explanation.\n- You MUST " \
              "output code exclusively.\n- The suggested code MUST work by simply concatenating to the provided " \
              "code.\n- You MUST not include any sort of markdown markup.\n- You MUST NOT repeat or modify any " \
              "part of the prefix or suffix.\n- You MUST only provide the missing code that fits between " \
              "them.\n\nIf you are not able to complete code based on the given instructions, return an " \
              "empty result.",
            "role" => "system"
          },
          {
            "content" => "<SUFFIX>\nsome content_above_cursor\n</SUFFIX>\n" \
              "<PREFIX>\nsome content_below_cursor\n</PREFIX>",
            "role" => "user"
          }
        ]
      }
    end

    it_behaves_like 'code suggestion task' do
      let(:expected_body) { anthropic_request_body }
      let(:expected_feature_name) { :code_suggestions }
    end
  end

  describe 'saas primary models' do
    before do
      stub_feature_flags(incident_fail_over_completion_provider: false)
    end

    let(:expected_feature_name) { :code_suggestions }

    let(:request_body_without_model_details) do
      {
        "current_file" => {
          "file_name" => "test.py",
          "content_above_cursor" => "sor",
          "content_below_cursor" => "som"
        },
        "prompt_version" => 1
      }
    end

    context 'when Fireworks/Qwen beta FF is enabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: true)
      end

      let(:model_engine) { 'fireworks-ai' }

      let(:request_body_for_fireworks_qwen_with_model_details) do
        request_body_without_model_details.merge(
          "model_name" => "qwen2p5-coder-7b",
          "model_provider" => "fireworks_ai",
          "telemetry" => [{ "model_engine" => "fireworks-ai" }]
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_body) { request_body_for_fireworks_qwen_with_model_details }
      end
    end

    context 'when Fireworks/Qwen beta FF is disabled' do
      before do
        stub_feature_flags(fireworks_qwen_code_completion: false)
      end

      let(:model_engine) { 'vertex-ai' }

      let(:request_body_for_vertex_codegecko) do
        request_body_without_model_details.merge(
          "telemetry" => [{ "model_engine" => "vertex-ai" }]
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_body) { request_body_for_vertex_codegecko }
      end
    end
  end

  describe 'self-hosted model' do
    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [],
        'stream' => false
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file
      }
    end

    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params
      )
    end

    let_it_be(:ai_self_hosted_model) do
      create(:ai_self_hosted_model, model: :codellama, name: 'whatever')
    end

    context 'on setting the provider as `self_hosted`' do
      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model,
          provider: :self_hosted
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_body) do
          {
            "current_file" => {
              "file_name" => "test.py",
              "content_above_cursor" => "sor",
              "content_below_cursor" => "som"
            },
            "telemetry" => [],
            "stream" => false,
            "model_provider" => "litellm",
            "prompt_version" => 2,
            "prompt" => nil,
            "model_endpoint" => "http://localhost:11434/v1",
            "model_identifier" => "provider/some-model",
            "model_name" => "codellama",
            "model_api_key" => "token"
          }
        end

        let(:expected_feature_name) { :self_hosted_models }
      end
    end

    context 'on setting the provider as `disabled`' do
      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model,
          provider: :disabled
        )
      end

      it 'is a disabled task' do
        expect(task.feature_disabled?).to eq(true)
      end
    end
  end
end
