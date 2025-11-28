# frozen_string_literal: true

module EE
  # ProjectsFinder
  #
  # Extends ProjectsFinder
  #
  # Added arguments:
  #   params:
  #     plans: string[]
  #     feature_available: string[]
  #     aimed_for_deletion: Symbol
  #     include_hidden: boolean
  #     filter_expired_saml_session_projects: boolean
  #     active: boolean - Whether to include projects that are neither archived or marked for deletion.
  #     with_duo_eligible: boolean - Whether to include projects that are eligible for Duo features.
  module ProjectsFinder
    include Gitlab::Auth::Saml::SsoSessionFilterable
    extend ::Gitlab::Utils::Override

    private

    override :filter_projects
    def filter_projects(collection)
      collection = super(collection)
      collection = by_plans(collection)
      collection = by_feature_available(collection)
      collection = by_hidden(collection)
      collection = by_duo_eligible(collection)
      by_saml_sso_session(collection)
    end

    def by_plans(collection)
      if names = params[:plans].presence
        collection.for_plan_name(names)
      else
        collection
      end
    end

    def by_feature_available(collection)
      if feature = params[:feature_available].presence
        collection.with_feature_available(feature)
      else
        collection
      end
    end

    def by_hidden(items)
      params[:include_hidden].present? ? items : items.not_hidden
    end

    def by_saml_sso_session(collection)
      filter_by_saml_sso_session(collection, :filter_expired_saml_session_projects)
    end

    def by_duo_eligible(items)
      return items unless ::Gitlab::Utils.to_boolean(params[:with_duo_eligible])

      return items unless ::Feature.enabled?(:with_duo_eligible_projects_filter, current_user)

      items.with_duo_features_enabled.joins_namespace.merge(
        ::Namespace.namespace_settings_with_ai_features_enabled.with_ai_supported_plan
      )
    end
  end
end
