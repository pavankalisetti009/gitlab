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
  #     with_code_embeddings_indexed: boolean - Whether to include projects that have indexed embeddings for their
  #       code. This requires the `project_ids_relation` parameter, passed in as an integer array
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
      collection = by_code_embeddings_indexed(collection)
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

    def by_code_embeddings_indexed(items)
      # return original projects relation if `with_code_embeddings_indexed` is false or FF is disabled
      return items if !::Gitlab::Utils.to_boolean(params[:with_code_embeddings_indexed]) || code_embeddings_disabled?

      # return empty project relation if `project_ids_relation` is invalid
      # project ids is required because active_context_code_repositories is a partitioned table
      # project_id is used to do the partition prune
      # additionally, we won't allow a relation because this would result in a nested query
      # and could mean that partitioning pruning isn't done
      return items.none if project_ids_relation.blank? || !project_ids_relation.is_a?(Array)

      items.with_ready_active_context_code_repository_project_ids project_ids_relation
    end

    def code_embeddings_disabled?
      !current_user.is_a?(User) || ::Feature.disabled?(:allow_with_code_embeddings_indexed_projects_filter,
        current_user)
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
