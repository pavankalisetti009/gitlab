# frozen_string_literal: true

FactoryBot.define do
  factory :ai_namespace_feature_setting, class: '::Ai::ModelSelection::NamespaceFeatureSetting' do
    association :namespace, factory: :group

    add_attribute(:feature) { :code_completions }

    offered_model_ref { 'claude_sonnet_3_7' }
    offered_model_name { 'Claude Sonnet 3.7' }

    model_definitions do
      {
        "models" => [
          { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
          { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude_sonnet_3_7' },
          { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude-3-7-sonnet-20250219' },
          { 'name' => 'Claude 3.5 Sonnet', 'identifier' => 'claude-3-5-sonnet-20240620' },
          { 'name' => 'Claude Sonnet 3.7 20250219', 'identifier' => 'claude_sonnet_3_7_20250219' },
          { 'name' => 'OpenAI Chat GPT 4o', 'identifier' => 'openai_chatgpt_4o' }
        ],
        "unit_primitives" => [
          {
            "feature_setting" => "code_completions",
            "default_model" => "claude_sonnet_3_5",
            "selectable_models" => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
            "beta_models" => [],
            "unit_primitives" => %w[ask_build ask_commit]
          },
          {
            "feature_setting" => "code_generations",
            "default_model" => "claude_sonnet_3_5",
            "selectable_models" => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
            "beta_models" => [],
            "unit_primitives" => ["generate_code"]
          },
          {
            "feature_setting" => "duo_chat_explain_code",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["explain_code"]
          },
          {
            "feature_setting" => "duo_chat",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude_3_5_sonnet_20240620],
            "beta_models" => [],
            "unit_primitives" => %w[ask_build ask_commit]
          },
          {
            "feature_setting" => "summarize_new_merge_request",
            "default_model" => "claude_sonnet_3_7_20250219",
            "selectable_models" => %w[claude_sonnet_3_7_20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["summarize_new_merge_request"]
          }
        ]
      }
    end
  end
end
