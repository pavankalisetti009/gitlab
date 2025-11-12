# frozen_string_literal: true

module Admin
  module Ai
    module SelfHostedModelsHelper
      MODEL_NAME_MAPPER = {
        "mistral" => "Mistral",
        "mixtral" => "Mixtral",
        "llama3" => "Llama 3",
        "codegemma" => "CodeGemma",
        "codestral" => "Mistral Codestral",
        "codellama" => "Code Llama",
        "deepseekcoder" => "DeepSeek Coder",
        "claude_3" => "Claude",
        "gpt" => "GPT",
        "general" => "General"
      }.freeze

      def model_choices_as_options
        model_options =
          ::Ai::SelfHostedModel.models.filter_map do |name, _|
            release_state = ::Ai::SelfHostedModel::MODELS_RELEASE_STATE[name.to_sym]

            next if release_state == ::Ai::SelfHostedModel::RELEASE_STATE_BETA && !beta_models_enabled?

            {
              modelValue: name.upcase,
              modelName: MODEL_NAME_MAPPER[name] || name.humanize,
              releaseState: release_state
            }
          end

        model_options.sort_by { |option| option[:modelName] }
      end

      def dedicated_instance?
        ::Gitlab::CurrentSettings.gitlab_dedicated_instance?
      end

      def show_self_hosted_vendored_model_option?
        false
      end

      def can_manage_instance_model_selection?
        ::Ability.allowed?(current_user, :manage_instance_model_selection)
      end

      def beta_models_enabled?
        ::Ai::TestingTermsAcceptance.has_accepted?
      end
    end
  end
end
