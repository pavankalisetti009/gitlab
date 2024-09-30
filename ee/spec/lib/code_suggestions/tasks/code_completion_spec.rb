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

  context 'when using self-hosted model' do
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
        create(:ai_self_hosted_model, model: :codellama, name: 'whatever')
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
          "model_identifier" => "provider/some-model",
          "model_name" => "codellama",
          "model_api_key" => "token"
        }
      end

      let(:expected_feature_name) { :self_hosted_models }
    end
  end
end
