# frozen_string_literal: true

module Gitlab
  module Llm
    class TanukiBot
      SCOPELESS_CONTROLLERS = %w[search].freeze

      def self.enabled_for?(user:, container: nil)
        return false unless chat_enabled?(user)

        authorizer_response = if container
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
                              else
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user)
                              end

        authorizer_response.allowed?
      end

      def self.agentic_mode_available?(user:, project:, group:)
        if project.present? && project.persisted?
          user.can?(:access_duo_agentic_chat, project)
        elsif group.present? && group.persisted?
          user.can?(:access_duo_agentic_chat, group)
        else
          false
        end
      end

      def self.show_breadcrumbs_entry_point?(user:)
        return false unless chat_enabled?(user)

        Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user).allowed?
      end

      def self.chat_disabled_reason(user:, container: nil)
        return unless container

        authorizer_response = Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
        return if authorizer_response.allowed?

        container.is_a?(Group) ? :group : :project
      end

      def self.chat_enabled?(user)
        return false unless user

        true
      end

      def self.namespace
        namespace_path = Gitlab::ApplicationContext.current_context_attribute(:root_namespace).presence
        return unless namespace_path

        Group.find_by_full_path(namespace_path)
      end

      def self.default_duo_namespace(user:)
        return unless user

        user.user_preference.duo_default_namespace_with_fallback
      end

      def self.user_model_selection_enabled?(user:, scope:)
        namespace_to_use = scope&.root_ancestor

        return false unless namespace_to_use
        return false if ::Feature.disabled?(:duo_agent_platform_model_selection, namespace_to_use)
        return false if ::Feature.disabled?(:ai_user_model_switching, user)

        result = ::Ai::FeatureSettingSelectionService
                            .new(
                              user,
                              ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name,
                              namespace_to_use
                            ).execute

        result.success? && result.payload.present? && result.payload.user_model_selection_available?
      end

      def self.resource_id
        Gitlab::ApplicationContext.current_context_attribute(:ai_resource).presence
      end

      def self.project_id
        project_path = Gitlab::ApplicationContext.current_context_attribute(:project).presence
        Project.find_by_full_path(project_path).try(:to_global_id) if project_path
      end

      def self.root_namespace_id(scope)
        return unless scope

        scope.root_ancestor.to_global_id
      end

      def self.duo_scope_hash(user, project, group, controller_name)
        if SCOPELESS_CONTROLLERS.include?(controller_name)
          { namespace: user.user_preference.duo_default_namespace_with_fallback }
        elsif project && project.persisted?
          { project: project }
        elsif group && group.persisted?
          { namespace: group }
        else # rubocop:disable Lint/DuplicateBranch -- readability
          { namespace: user.user_preference.duo_default_namespace_with_fallback }
        end
      end
    end
  end
end
