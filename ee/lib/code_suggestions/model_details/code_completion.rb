# frozen_string_literal: true

module CodeSuggestions
  module ModelDetails
    class CodeCompletion < Base
      FEATURE_SETTING_NAME = 'code_completions'

      def initialize(current_user:)
        super(current_user: current_user, feature_setting_name: FEATURE_SETTING_NAME)
      end

      # Returns model details for using direct connection in the IDE.
      # Note: Claude Haiku cannot use direct connect so isn't used in this function
      def current_model
        # if self-hosted, the model details are provided by the client
        return {} if self_hosted?

        return fireworks_codestral_2501_model_details if use_fireworks_codestral_for_code_completions?

        return fireworks_qwen_2_5_model_details if use_fireworks_qwen_for_code_completions?

        return vertex_codestral_2501_model_details if code_gecko_disabled? && fireworks_opt_out?

        # the default behavior is returning an empty hash
        # AI Gateway will fall back to a default model if model details are not provided
        {}
      end

      def saas_primary_model_class
        return if self_hosted?

        if any_user_groups_claude_code_completion?
          return CodeSuggestions::Prompts::CodeCompletion::Anthropic::ClaudeHaiku
        end

        if use_fireworks_codestral_for_code_completions?
          return CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral
        end

        return CodeSuggestions::Prompts::CodeCompletion::FireworksQwen if use_fireworks_qwen_for_code_completions?

        return CodeSuggestions::Prompts::CodeCompletion::VertexCodestral if code_gecko_disabled? && fireworks_opt_out?

        CodeSuggestions::Prompts::CodeCompletion::VertexAi
      end

      # We check :use_claude_code_completion by the top level group
      def any_user_groups_claude_code_completion?
        user_duo_groups.any? do |group|
          Feature.enabled?(:use_claude_code_completion, group)
        end
      end

      private

      def fireworks_qwen_2_5_model_details
        {
          model_provider: CodeSuggestions::Prompts::CodeCompletion::FireworksQwen::MODEL_PROVIDER,
          model_name: CodeSuggestions::Prompts::CodeCompletion::FireworksQwen::MODEL_NAME
        }
      end

      def fireworks_codestral_2501_model_details
        {
          model_provider: CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral::MODEL_PROVIDER,
          model_name: CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral::MODEL_NAME
        }
      end

      def vertex_codestral_2501_model_details
        {
          model_provider: CodeSuggestions::Prompts::CodeCompletion::VertexCodestral::MODEL_PROVIDER,
          model_name: CodeSuggestions::Prompts::CodeCompletion::VertexCodestral::MODEL_NAME
        }
      end

      # For :code_completion_opt_out_fireworks and :code_completion_model_opt_out_from_fireworks_qwen
      # On GitLab SaaS, Duo access is managed by top-level group,
      #   so we are checking the FF by the user's top-level group
      # On GitLab self-managed, Duo access is managed on an instance level;
      #   while we can check the FF on the instance level, we will follow
      #   FF development recommendations and check by the user actor
      def fireworks_opt_out?
        code_completion_model_opt_out_from_fireworks_qwen? ||
          code_completion_opt_out_fireworks?
      end

      def use_fireworks_codestral_for_code_completions?
        return false if Feature.disabled?(:use_fireworks_codestral_code_completion, current_user, type: :beta)

        !code_completion_opt_out_fireworks?
      end

      def use_fireworks_qwen_for_code_completions?
        # check the beta FF against the current user and immediately return false if disabled
        return false if Feature.disabled?(:fireworks_qwen_code_completion, current_user, type: :beta)

        # if the beta FF is enabled, proceed to check the ops FF
        !code_completion_model_opt_out_from_fireworks_qwen?
      end

      def code_gecko_disabled?
        Feature.enabled?(:disable_code_gecko_default, current_user, type: :beta)
      end

      # The opt out code below has to be written twice to avoid RuboCop::Cop::Gitlab::MarkUsedFeatureFlags
      # since it cannot handle feature flag names in variables

      # For code_completion_opt_out_fireworks
      # check if user's groups or instance has opted out of Fireworks
      def code_completion_opt_out_fireworks?
        # on saas, check the user's groups
        return any_user_groups_code_completion_opt_out_fireworks? if Gitlab.org_or_com? # rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- see comment above method definition

        # on self-managed, check the ops FF against the entire instance
        instance_code_completion_opt_out_fireworks?
      end

      def any_user_groups_code_completion_opt_out_fireworks?
        user_duo_groups.any? do |group|
          Feature.enabled?(:code_completion_opt_out_fireworks, group, type: :ops)
        end
      end

      def instance_code_completion_opt_out_fireworks?
        Feature.enabled?(:code_completion_opt_out_fireworks, :instance, type: :ops)
      end

      # For code_completion_model_opt_out_from_fireworks_qwen
      # check if user's groups or instance has opted out of Fireworks/Qwen
      def code_completion_model_opt_out_from_fireworks_qwen?
        # on saas, check the user's groups
        return any_user_groups_code_completion_model_opt_out_from_fireworks_qwen? if Gitlab.org_or_com? # rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- see comment above method definition

        # on self-managed, check the ops FF against the entire instance
        instance_code_completion_model_opt_out_from_fireworks_qwen?
      end

      def any_user_groups_code_completion_model_opt_out_from_fireworks_qwen?
        user_duo_groups.any? do |group|
          Feature.enabled?(:code_completion_model_opt_out_from_fireworks_qwen, group, type: :ops)
        end
      end

      def instance_code_completion_model_opt_out_from_fireworks_qwen?
        Feature.enabled?(:code_completion_model_opt_out_from_fireworks_qwen, :instance, type: :ops)
      end

      # fetches all the top-level groups that give the user Duo Access
      #   - the User#duo_available_namespace_ids method queries the `subscription_user_add_on_assignments`
      #     by user_id and filters to active gitlab duo pro and enterprise add-ons
      #   - the `subscription_user_add_on_assignments` has a `subscription_add_on_purchases`, which has a `namespace_id`
      #   - `subscription_add_on_purchases.namespace_id` is:
      #     - always set on SaaS (https://gitlab.com/gitlab-org/gitlab/-/merge_requests/123778)
      #     - and not set on self-managed (https://gitlab.com/gitlab-org/gitlab/-/merge_requests/128899)
      def user_duo_groups
        @user_duo_groups ||= Group.by_id(current_user.duo_available_namespace_ids)
      end
    end
  end
end
