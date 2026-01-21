# frozen_string_literal: true

FactoryBot.define do
  factory :ai_feature_setting, class: '::Ai::FeatureSetting' do
    add_attribute(:feature) { :code_generations }
    provider { :self_hosted }
    self_hosted_model { provider.to_sym == :self_hosted ? association(:ai_self_hosted_model) : nil }

    trait :duo_agent_platform do
      add_attribute(:feature) { :duo_agent_platform }
    end

    trait :duo_agent_platform_agentic_chat do
      add_attribute(:feature) { :duo_agent_platform_agentic_chat }
    end
  end
end
