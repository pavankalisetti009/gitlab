# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      module ModelSwitching
        class AiGateway < CodeSuggestions::Prompts::Base
          include CodeSuggestions::Prompts::CodeCompletion::Anthropic::Concerns::Prompt

          GATEWAY_PROMPT_VERSION = 3
          MODEL_PROVIDER = 'gitlab'
          GITLAB_PROVIDED_CLAUDE_HAIKU_MODEL_NAME = 'claude_3_5_haiku_20241022'
          GITLAB_PROVIDED_ANTHROPIC_MODELS_FOR_CODE_COMPLETION = [
            GITLAB_PROVIDED_CLAUDE_HAIKU_MODEL_NAME,
            'claude_sonnet_3_7_20250219',
            'claude_3_5_sonnet_20240620'
          ].freeze

          def initialize(params, current_user, feature_setting, user_group_with_claude_code_completion)
            @user_group_with_claude_code_completion = user_group_with_claude_code_completion
            super(params, current_user, feature_setting)
          end

          def request_params
            {
              model_provider: self.class::MODEL_PROVIDER,
              model_name: model_name.to_s,
              prompt_version: self.class::GATEWAY_PROMPT_VERSION,
              prompt: find_prompt
            }
          end

          private

          attr_reader :user_group_with_claude_code_completion

          def find_prompt
            # We still need to pass the prompt due to legacy reasons, but only for Anthropic models.
            # See https://gitlab.com/gitlab-org/gitlab/-/issues/548241#note_2553250550 for details.
            return unless GITLAB_PROVIDED_ANTHROPIC_MODELS_FOR_CODE_COMPLETION.include?(model_name.to_s)

            prompt
          end

          def model_name
            # Currently, only "pinned" models are served via this code path.
            # Even when a model is pinned, we should adhere to specific group rules that are set
            # in place by the customer, via feature flags.
            if user_group_with_claude_code_completion.present?
              namespace_feature_setting_from_user_group =
                ::Ai::ModelSelection::NamespaceFeatureSetting.find_or_initialize_by_feature(
                  user_group_with_claude_code_completion, :code_completions)

              # Once we have made sure that the customers using the `use_claude_code_completion`
              # have pinned a model for code completion, this return statement can be removed.
              if namespace_feature_setting_from_user_group.set_to_gitlab_default?
                return GITLAB_PROVIDED_CLAUDE_HAIKU_MODEL_NAME
              end
            end

            namespace_feature_setting_from_user_group&.offered_model_ref || feature_setting.offered_model_ref
          end
        end
      end
    end
  end
end
