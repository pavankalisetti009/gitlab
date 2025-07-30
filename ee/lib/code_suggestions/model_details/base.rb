# frozen_string_literal: true

module CodeSuggestions
  module ModelDetails
    class Base
      include Gitlab::Utils::StrongMemoize

      def initialize(current_user:, feature_setting_name:, root_namespace: nil)
        @current_user = current_user
        @feature_setting_name = feature_setting_name
        @root_namespace = root_namespace
      end

      def feature_setting
        model_selection_feature_setting || self_hosted_feature_setting
      end
      strong_memoize_attr :feature_setting

      def base_url
        feature_setting&.base_url || ::Gitlab::AiGateway.url
      end

      def feature_name
        return :amazon_q_integration if ::Ai::AmazonQ.connected?
        return :self_hosted_models if self_hosted?

        :code_suggestions
      end

      def licensed_feature
        return :amazon_q if ::Ai::AmazonQ.connected?

        :ai_features
      end

      def feature_disabled?
        # In case the code suggestions feature is being used via self-hosted models,
        # it can also be disabled completely. In such cases, this check
        # can be used to prevent exposing the feature via UI/API.
        !!feature_setting&.disabled?
      end

      def self_hosted?
        !!feature_setting&.self_hosted?
      end

      def vendored?
        !!feature_setting&.vendored?
      end

      def namespace_feature_setting?
        feature_setting.is_a?(::Ai::ModelSelection::NamespaceFeatureSetting)
      end

      def duo_context_not_found?
        return false if ::Ai::AmazonQ.connected?
        return false if self_hosted_feature_setting.present?
        # we need to return true only when there is multiple seats assigned to the user.
        # Otherwise, we might have false positives e.g. when self-hosted feature setting are not correctly set
        return false if current_user.user_preference.no_eligible_duo_add_on_assignments?

        model_selection_scoped_namespace.nil?
      end

      private

      attr_reader :current_user, :feature_setting_name, :root_namespace

      def model_selection_feature_setting
        namespace = model_selection_scoped_namespace

        return unless namespace

        ::Ai::ModelSelection::NamespaceFeatureSetting.find_or_initialize_by_feature(namespace, feature_setting_name)
      end

      def self_hosted_feature_setting
        ::Ai::FeatureSetting.find_by_feature(feature_setting_name)
      end
      strong_memoize_attr :self_hosted_feature_setting

      def model_selection_scoped_namespace
        return root_namespace if root_namespace

        # if no root_namespace provided self_hosted feature_settings should have precedence
        return if self_hosted_feature_setting

        # infer or find a default namespace if neither a root_namespace or a self_hosted setting is present
        current_user.user_preference.get_default_duo_namespace
      end
      strong_memoize_attr :model_selection_scoped_namespace
    end
  end
end
