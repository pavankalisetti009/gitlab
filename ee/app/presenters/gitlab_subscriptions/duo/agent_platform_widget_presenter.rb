# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    class AgentPlatformWidgetPresenter
      include Gitlab::Utils::StrongMemoize

      def initialize(user)
        @user = user
      end

      def attributes
        presenter.attributes
      end

      private

      attr_reader :user

      def presenter
        if authorized_self_managed?
          GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter.new(user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
        elsif self_managed?
          GitlabSubscriptions::Duo::SelfManaged::AgentPlatformWidgetPresenter.new(user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
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
    end
  end
end
