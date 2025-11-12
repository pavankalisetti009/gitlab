# frozen_string_literal: true

module Ai
  class FeatureSettingSelectionService
    MISSING_DEFAULT_NAMESPACE = "missing_default_namespace"

    def initialize(current_user, feature, root_namespace)
      @current_user = current_user
      @feature = feature
      @root_namespace = root_namespace
    end

    def execute
      return ServiceResponse.success(payload: nil) if ::Ai::AmazonQ.connected?

      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        feature_setting = model_selection_namespace_setting

        return ServiceResponse.success(payload: feature_setting) if feature_setting

        if default_duo_namespace_required?
          return ServiceResponse.error(payload: nil, message: MISSING_DEFAULT_NAMESPACE)
        end

        ServiceResponse.success(payload: nil)
      else
        # First check if a self-hosted model is defined for the feature
        feature_setting = self_hosted_feature_setting

        return ServiceResponse.success(payload: feature_setting) if feature_setting && !feature_setting.vendored?

        instance_setting = instance_level_setting

        # When a Self-hosted AI Gateway has been configured (for the instance), then we don't default to vendored
        # vendored becomes the default only on pure cloud-connected SM/dedicated instances. The same for offline
        # cloud license, since there's no connection to vendored models
        if ::License.current&.offline_cloud_license? ||
            (instance_setting.set_to_gitlab_default? && Gitlab::AiGateway.has_self_hosted_ai_gateway?)
          return ServiceResponse.success(payload: nil)
        end

        # Instance level is fetched either when we don't have a feature_setting, or when it is set to vendored
        ServiceResponse.success(payload: instance_setting)
      end
    end

    private

    def model_selection_namespace_setting
      namespace = model_selection_namespace

      return if namespace.nil?

      ::Ai::ModelSelection::NamespaceFeatureSetting.find_or_initialize_by_feature(namespace, @feature)
    end

    def model_selection_namespace
      @root_namespace || default_duo_namespace
    end

    def instance_level_setting
      ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting.find_or_initialize_by_feature(@feature)
    end

    def self_hosted_feature_setting
      ::Ai::FeatureSetting.find_by_feature(@feature)
    end

    def default_duo_namespace
      @current_user.user_preference.get_default_duo_namespace
    end

    def default_duo_namespace_required?
      # we need to return the default namespace only when there is multiple seats assigned to the user.
      # Otherwise, we might have error in undesirable cases
      # e.g. when self-hosted feature setting are not correctly set
      return false if default_duo_namespace

      # if any of the assigned seat has a namespace with model switching enable
      # it is required for the user to have a default namespace to be selected.
      # This logic is in EE::UserPolicy#can_assign_default_duo_group?
      Ability.allowed?(@current_user, :assign_default_duo_group, @current_user)
    end
  end
end
