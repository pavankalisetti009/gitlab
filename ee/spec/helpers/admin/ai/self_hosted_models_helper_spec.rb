# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::Ai::SelfHostedModelsHelper, feature_category: :"self-hosted_models" do
  let(:user) { build(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
    allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
  end

  describe '#model_choices_as_options' do
    it 'returns an array of hashes with model options sorted alphabetically' do
      expected_result = [
        { modelValue: "CLAUDE_3", modelName: "Claude", releaseState: "GA" },
        { modelValue: "CODELLAMA", modelName: "Code Llama", releaseState: "BETA" },
        { modelValue: "CODEGEMMA", modelName: "CodeGemma", releaseState: "BETA" },
        { modelValue: "DEEPSEEKCODER", modelName: "DeepSeek Coder", releaseState: "BETA" },
        { modelValue: "GPT", modelName: "GPT", releaseState: "GA" },
        { modelValue: "GENERAL", modelName: "General", releaseState: "BETA" },
        { modelValue: "LLAMA3", modelName: "Llama 3", releaseState: "BETA" },
        { modelValue: "MISTRAL", modelName: "Mistral", releaseState: "GA" },
        { modelValue: "CODESTRAL", modelName: "Mistral Codestral", releaseState: "GA" },
        { modelValue: "MIXTRAL", modelName: "Mixtral", releaseState: "GA" }
      ]

      expect(helper.model_choices_as_options).to eq(expected_result)
    end

    it 'humanizes the model name when there is no mapped name available' do
      allow(::Ai::SelfHostedModel).to receive(:models).and_return(["unmapped_model"])

      expect(helper.model_choices_as_options).to eq([
        {
          modelValue: "UNMAPPED_MODEL",
          modelName: "Unmapped model",
          releaseState: nil
        }
      ])
    end

    it 'filters out beta models if they are not enabled' do
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)

      expect(helper.model_choices_as_options).to eq([
        { modelValue: "CLAUDE_3", modelName: "Claude", releaseState: "GA" },
        { modelValue: "GPT", modelName: "GPT", releaseState: "GA" },
        { modelValue: "MISTRAL", modelName: "Mistral", releaseState: "GA" },
        { modelValue: "CODESTRAL", modelName: "Mistral Codestral", releaseState: "GA" },
        { modelValue: "MIXTRAL", modelName: "Mixtral", releaseState: "GA" }
      ])
    end
  end

  describe '#can_manage_instance_model_selection?' do
    it 'returns false if ability is not allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_instance_model_selection).and_return(false)
      expect(helper.can_manage_instance_model_selection?).to be(false)
    end

    it 'returns true if ability is allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_instance_model_selection).and_return(true)
      expect(helper.can_manage_instance_model_selection?).to be(true)
    end
  end

  describe '#can_manage_self_hosted_models?' do
    it 'returns false if ability is not allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_self_hosted_models_settings).and_return(false)
      expect(helper.can_manage_self_hosted_models?).to be(false)
    end

    it 'returns true if ability is allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_self_hosted_models_settings).and_return(true)
      expect(helper.can_manage_self_hosted_models?).to be(true)
    end
  end

  describe '#beta_models_enabled?' do
    it 'returns true if testing terms have been accepted' do
      expect(helper.beta_models_enabled?).to be(true)
    end

    it 'returns false if testing terms have not been accepted' do
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)

      expect(helper.beta_models_enabled?).to be(false)
    end
  end
end
