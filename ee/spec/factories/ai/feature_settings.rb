# frozen_string_literal: true

FactoryBot.define do
  factory :ai_feature_setting, class: '::Ai::FeatureSetting' do
    add_attribute(:feature) { :code_generations }
    provider { :self_hosted }
    self_hosted_model factory: :ai_self_hosted_model

    trait :duo_agent_platform do
      add_attribute(:feature) { :duo_agent_platform }
    end
  end
end
