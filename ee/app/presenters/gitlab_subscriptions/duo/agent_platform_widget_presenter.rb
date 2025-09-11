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
        if authorized_self_managed?
          GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter.new(user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
        elsif self_managed?
          GitlabSubscriptions::Duo::SelfManaged::AgentPlatformWidgetPresenter.new(user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
        elsif authorized_gitlab_com?
          GitlabSubscriptions::Duo::GitlabCom::AuthorizedAgentPlatformWidgetPresenter.new(user, context) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
        else
          {}.tap { |h| h.define_singleton_method(:attributes) { self } } # placeholder while we iterate on the widget
        end
      end

      def authorized_self_managed?
        self_managed? && Ability.allowed?(user, :admin_all_resources)
      end

      def self_managed?
        !::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
      end

      def authorized_gitlab_com?
        return false unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
        return false unless context
        return false if context.is_a?(Project)
        return false unless context.root?

        Ability.allowed?(user, :admin_namespace, context)
      end
    end
  end
end
