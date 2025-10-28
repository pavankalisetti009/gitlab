# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class DuoAgentPlatformModelMetadataService
      FEATURE_NAME = :duo_agent_platform

      def initialize(root_namespace: nil, current_user: nil, user_selected_model_identifier: nil)
        @root_namespace = root_namespace
        @current_user = current_user
        @user_selected_model_identifier = user_selected_model_identifier.to_s
      end

      def execute
        return resolve_self_managed_model_metadata if self_managed?

        resolve_gitlab_com_model_metadata
      end

      private

      attr_reader :root_namespace, :current_user, :user_selected_model_identifier

      def self_managed?
        !::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      def duo_agent_platform_in_self_hosted_duo?
        ::Ai::FeatureSetting.duo_agent_platform.self_hosted.exists?
      end

      def resolve_self_managed_model_metadata
        if duo_agent_platform_in_self_hosted_duo?
          resolve_self_hosted_duo_model_metadata
        else
          resolve_cloud_connected_model_metadata
        end
      end

      # Self-Hosted Duo Priority:
      # 1. Self-hosted feature setting (admin-configured models only)
      # Note: No user model selection - limited to what admin sets up
      def resolve_self_hosted_duo_model_metadata
        return {} unless Feature.enabled?(:self_hosted_agent_platform, :instance)

        feature_setting = ::Ai::FeatureSetting.find_by_feature(FEATURE_NAME)

        model_metadata_from_setting(feature_setting)
      end

      # Cloud-Connected Self-Managed Priority (same user empowerment as GitLab.com):
      # 1. Instance-level model selection (admin sets instance defaults)
      # 2. User model selection (users can override instance defaults)
      def resolve_cloud_connected_model_metadata
        return {} unless Feature.enabled?(:instance_level_model_selection, :instance)

        # Priority 1: Instance-level model selection
        instance_setting = ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting
                            .find_or_initialize_by_feature(FEATURE_NAME)

        return {} unless instance_setting

        resolve_model_metadata_with_user_selection(instance_setting, model_selection_scope: nil)
      end

      # GitLab.com Priority:
      # 1. Namespace-level model selection (organization/group defaults)
      # 2. User model selection (users can override namespace defaults)
      def resolve_gitlab_com_model_metadata
        return {} unless root_namespace

        return {} unless Feature.enabled?(:duo_agent_platform_model_selection, root_namespace)
        # Priority 1: Namespace-level model selection
        return {} unless Feature.enabled?(:ai_model_switching, root_namespace)

        namespace_setting = ::Ai::ModelSelection::NamespaceFeatureSetting
                             .find_or_initialize_by_feature(root_namespace, FEATURE_NAME)

        return {} unless namespace_setting

        resolve_model_metadata_with_user_selection(namespace_setting, model_selection_scope: root_namespace)
      end

      def resolve_model_metadata_with_user_selection(setting, model_selection_scope:)
        setting_metadata = model_metadata_from_setting(setting)

        return setting_metadata if do_not_consider_user_selected_model?(setting, model_selection_scope)

        # Priority 2: User model selection
        user_selected_model_metadata(model_selection_scope)
      end

      def model_metadata_from_setting(setting_record)
        ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
          feature_setting: setting_record
        ).execute
      end

      def do_not_consider_user_selected_model?(setting, model_selection_scope)
        setting.pinned_model? ||
          user_model_selection_disabled? ||
          invalid_user_selected_model_identifier?(model_selection_scope)
      end

      def user_model_selection_disabled?
        Feature.disabled?(:ai_user_model_switching, current_user)
      end

      def invalid_user_selected_model_identifier?(model_selection_scope)
        return true if user_selected_model_identifier.blank?

        selectable_models(model_selection_scope).exclude?(user_selected_model_identifier)
      end

      def selectable_models(model_selection_scope)
        result = ::Ai::ModelSelection::FetchModelDefinitionsService
                    .new(current_user, model_selection_scope: model_selection_scope)
                    .execute

        return [] unless result&.success?

        parsed_response =
          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(result.payload)

        parsed_response.selectable_models_for_feature(FEATURE_NAME)
      end

      def user_selected_model_metadata(model_selection_scope)
        record = build_record_with_user_selected_model_identifier(model_selection_scope)

        model_metadata_from_setting(record)
      end

      def build_record_with_user_selected_model_identifier(model_selection_scope)
        if model_selection_scope
          ::Ai::ModelSelection::NamespaceFeatureSetting.build(
            namespace: model_selection_scope,
            feature: FEATURE_NAME,
            offered_model_ref: user_selected_model_identifier
          )
        else
          ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting.build(
            feature: FEATURE_NAME,
            offered_model_ref: user_selected_model_identifier
          )
        end
      end
    end
  end
end
