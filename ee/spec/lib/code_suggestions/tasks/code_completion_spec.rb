# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::CodeCompletion, feature_category: :code_suggestions do
  let(:endpoint_path) { 'v2/code/completions' }

  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => 'some prefix',
      'content_below_cursor' => 'some suffix'
    }.with_indifferent_access
  end

  let(:expected_current_file) do
    { current_file: { file_name: 'test.py', content_above_cursor: 'fix', content_below_cursor: 'som' } }
  end

  before do
    stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
  end

  context 'when using saas model Vertex' do
    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [{ 'model_engine' => 'vertex-ai' }]
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file,
        code_completion_model_family: model_family
      }
    end

    let(:model_family) { :vertex_ai }
    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params
      )
    end

    context "when using codegecko for code suggestion task" do
      before do
        stub_feature_flags(use_codestral_for_code_completions: false)
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_body) do
          {
            "current_file" => {
              "file_name" => "test.py",
              "content_above_cursor" => "fix",
              "content_below_cursor" => "som"
            },
            "telemetry" => [{ "model_engine" => "vertex-ai" }],
            "prompt_version" => 1
          }
        end

        let(:expected_feature_name) { :code_suggestions }
      end
    end

    context "when using codestral for code suggestion task" do
      before do
        stub_feature_flags(use_codestral_for_code_completions: true)
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_body) do
          {
            "model_name" => "codestral@2405",
            "model_provider" => "vertex-ai",
            "current_file" => {
              "file_name" => "test.py",
              "content_above_cursor" => "fix",
              "content_below_cursor" => "som"
            },
            "telemetry" => [{ "model_engine" => "vertex-ai" }],
            "prompt_version" => 1
          }
        end

        let(:expected_feature_name) { :code_suggestions }
      end
    end
  end

  context 'when using self-hosted model codegemma_7b' do
    before do
      stub_feature_flags(ai_custom_models_prompts_migration: false)
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
        current_file: current_file
      }
    end

    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params
      )
    end

    it_behaves_like 'code suggestion task' do
      let_it_be(:ai_self_hosted_model) { create(:ai_self_hosted_model, model: :codegemma_7b, name: 'whatever') }
      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model
        )
      end

      let(:expected_body) do
        {
          "current_file" => {
            "file_name" => "test.py",
            "content_above_cursor" => "fix",
            "content_below_cursor" => "som"
          },
          "telemetry" => [],
          "stream" => false,
          "model_provider" => "litellm",
          "prompt_version" => 2,
          "prompt" => "<|fim_prefix|>some prefix<|fim_suffix|>some suffix<|fim_middle|>",
          "model_endpoint" => "http://localhost:11434/v1",
          "model_name" => "codegemma_7b",
          "model_api_key" => "token"
        }
      end

      let(:expected_feature_name) { :self_hosted_models }
    end
  end

  context 'when using self-hosted model codestral' do
    before do
      stub_feature_flags(ai_custom_models_prompts_migration: false)
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
        current_file: current_file
      }
    end

    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params
      )
    end

    it_behaves_like 'code suggestion task' do
      let_it_be(:ai_self_hosted_model) { create(:ai_self_hosted_model, model: :codestral, name: 'whatever') }
      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model
        )
      end

      let(:expected_body) do
        {
          "current_file" => {
            "file_name" => "test.py",
            "content_above_cursor" => "fix",
            "content_below_cursor" => "som"
          },
          "telemetry" => [],
          "stream" => false,
          "model_provider" => "litellm",
          "prompt_version" => 2,
          "prompt" => "<s>[SUFFIX]some suffix[PREFIX]some prefix",
          "model_endpoint" => "http://localhost:11434/v1",
          "model_name" => "codestral",
          "model_api_key" => "token"
        }
      end

      let(:expected_feature_name) { :self_hosted_models }
    end
  end

  context 'when using self-hosted model codellama' do
    before do
      stub_feature_flags(ai_custom_models_prompts_migration: false)
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
        current_file: current_file
      }
    end

    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params
      )
    end

    it_behaves_like 'code suggestion task' do
      let_it_be(:ai_self_hosted_model) do
        create(:ai_self_hosted_model, model: :codellama_13b_code, name: 'whatever')
      end

      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model
        )
      end

      let(:expected_body) do
        {
          "current_file" => {
            "file_name" => "test.py",
            "content_above_cursor" => "fix",
            "content_below_cursor" => "som"
          },
          "telemetry" => [],
          "stream" => false,
          "model_provider" => "litellm",
          "prompt_version" => 2,
          "prompt" => "<PRE> some prefix <SUF>some suffix <MID>",
          "model_endpoint" => "http://localhost:11434/v1",
          "model_name" => "codellama_13b_code",
          "model_api_key" => "token"
        }
      end

      let(:expected_feature_name) { :self_hosted_models }
    end
  end

  context 'when model name is unknown' do
    before do
      stub_feature_flags(ai_custom_models_prompts_migration: false)
      allow(Ai::FeatureSetting).to receive(:find_by_feature).with(:code_completions).and_return(ai_feature_setting)
      allow(ai_feature_setting).to receive_message_chain(:self_hosted_model, :model, :to_sym).and_return("unknown")
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
        current_file: current_file
      }
    end

    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params
      )
    end

    let(:ai_feature_setting) do
      instance_double(Ai::FeatureSetting, self_hosted?: true)
    end

    it 'raises an error' do
      expect { task.body }.to raise_error("Unknown model: unknown")
    end
  end

  context 'when using self-hosted model enable ai_custom_models_prompts_migration' do
    before do
      stub_feature_flags(ai_custom_models_prompts_migration: true)
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
        current_file: current_file
      }
    end

    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params
      )
    end

    it_behaves_like 'code suggestion task' do
      let_it_be(:ai_self_hosted_model) do
        create(:ai_self_hosted_model, model: :codellama_13b_code, name: 'whatever')
      end

      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model
        )
      end

      let(:expected_body) do
        {
          "current_file" => {
            "file_name" => "test.py",
            "content_above_cursor" => "fix",
            "content_below_cursor" => "som"
          },
          "telemetry" => [],
          "stream" => false,
          "model_provider" => "litellm",
          "prompt_version" => 2,
          "prompt" => nil,
          "model_endpoint" => "http://localhost:11434/v1",
          "model_name" => "codellama_13b_code",
          "model_api_key" => "token"
        }
      end

      let(:expected_feature_name) { :self_hosted_models }
    end
  end
end
