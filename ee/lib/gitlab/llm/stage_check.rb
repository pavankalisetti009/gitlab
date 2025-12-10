# frozen_string_literal: true

module Gitlab
  module Llm
    class StageCheck
      class << self
        def available?(container, feature, user: nil)
          root_ancestor = container.root_ancestor

          return false if personal_namespace?(root_ancestor)
          return false unless root_ancestor.licensed_feature_available?(license_feature_name(feature))

          available_on_experimental_stage?(root_ancestor, feature, user: user) ||
            available_on_beta_stage?(root_ancestor, feature, user: user) ||
            available_on_ga_stage?(feature, user: user)
        end

        private

        def personal_namespace?(root_ancestor)
          root_ancestor.user_namespace?
        end

        def available_on_experimental_stage?(root_ancestor, feature, user: nil)
          return false unless instance_allows_experiment_and_beta_features
          return false unless gitlab_com_namespace_enables_experiment_and_beta_features(root_ancestor)
          return false unless available_on_stage?(feature, :experimental, user: user)

          true
        end

        # There is no beta setting yet.
        # https://gitlab.com/gitlab-org/gitlab/-/issues/409929
        def available_on_beta_stage?(root_ancestor, feature, user: nil)
          return false unless instance_allows_experiment_and_beta_features
          return false unless gitlab_com_namespace_enables_experiment_and_beta_features(root_ancestor)
          return false unless available_on_stage?(feature, :beta, user: user)

          true
        end

        def available_on_ga_stage?(feature, user: nil)
          return true if available_on_stage?(feature, :ga, user: user)

          false
        end

        def license_feature_name(feature)
          case feature
          when :chat
            :ai_chat
          when :agentic_chat
            :agentic_chat
          when :ai_catalog, :ai_catalog_flows
            :ai_catalog
          when :duo_workflow
            :ai_workflows
          when :glab_ask_git_command
            :glab_ask_git_command
          when :generate_commit_message
            :generate_commit_message
          when :summarize_new_merge_request
            :summarize_new_merge_request
          when :summarize_review
            :summarize_review
          when :generate_description
            :generate_description
          when :summarize_comments
            :summarize_comments
          when :review_merge_request
            :review_merge_request
          else
            :ai_features
          end
        end

        def instance_allows_experiment_and_beta_features
          if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
            true
          else
            ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
          end
        end

        def gitlab_com_namespace_enables_experiment_and_beta_features(namespace)
          # namespace-level settings check is only relevant for .com
          return true unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)

          if namespace.experiment_features_enabled
            true
          else
            false
          end
        end

        def available_on_stage?(feature, maturity, user: nil)
          if Feature.enabled?(:agentic_chat_ga) && feature == :agentic_chat # rubocop:disable Gitlab/FeatureFlagWithoutActor -- We can't easily tie this to an actor
            return :ga == maturity
          end

          effective_maturity = ::Gitlab::Llm::Utils::AiFeaturesCatalogue.effective_maturity(
            feature,
            user: user
          )
          effective_maturity == maturity
        end
      end
    end
  end
end

# Added for JiHu
::Gitlab::Llm::StageCheck.prepend_mod
