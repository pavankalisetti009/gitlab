# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    class AgentPlatformWidgetPresenter
      include Gitlab::Utils::StrongMemoize

      def initialize(user, context:)
        @user = user
        @context = context
      end

      def attributes
        presenter.attributes
      end

      private

      attr_reader :user, :context

      def presenter
        if authorized_gitlab_com?
          GitlabSubscriptions::Duo::GitlabCom::AuthorizedAgentPlatformWidgetPresenter.new(user, context) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
        elsif displayable_on_gitlab_com?
          GitlabSubscriptions::Duo::GitlabCom::AgentPlatformWidgetPresenter.new(user, context) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
        else
          {}.tap { |h| h.define_singleton_method(:attributes) { self } }
        end
      end

      def authorized_gitlab_com?
        display_context_valid_for_gitlab_com? && Ability.allowed?(user, :admin_namespace, context)
      end

      def displayable_on_gitlab_com?
        return false unless display_context_valid_for_gitlab_com?
        return false if Ability.allowed?(user, :admin_namespace, context)

        Ability.allowed?(user, :read_namespace_via_membership, context)
      end

      def display_context_valid_for_gitlab_com?
        return false unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
        return false unless context
        return false if context.is_a?(Project)

        context.root?
      end
    end
  end
end
