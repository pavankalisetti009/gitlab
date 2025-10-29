# frozen_string_literal: true

module GitlabSubscriptions
  class UpgradePresenter < Gitlab::View::Presenter::Simple
    def initialize(user, namespace: nil)
      @mediator = build_mediator(user, namespace)
    end

    delegate :attributes, to: :mediator

    private

    attr_reader :mediator

    def build_mediator(user, namespace)
      return SelfManagedMediator.new unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      if namespace.present?
        NamespaceMediator.new(user, namespace)
      else
        GlobalMediator.new(user)
      end
    end

    class SelfManagedMediator
      def attributes
        {}
      end
    end

    class NamespaceMediator
      def initialize(user, namespace)
        @user = user
        @namespace = namespace
      end

      def attributes
        return {} unless eligible_for_upgrade?

        { upgrade_url: ::Gitlab::Routing.url_helpers.group_billings_path(namespace) }
      end

      private

      attr_reader :user, :namespace

      def eligible_for_upgrade?
        return false unless namespace.persisted?

        (!namespace.paid? || namespace.trial?) && Ability.allowed?(user, :edit_billing, namespace)
      end
    end

    class GlobalMediator
      include Gitlab::Utils::StrongMemoize

      def initialize(user)
        @user = user
      end

      def attributes
        return {} unless has_upgradeable_groups?

        { upgrade_url: owned_groups_url }
      end

      private

      attr_reader :user

      def has_upgradeable_groups?
        owned_groups_url.present?
      end

      def owned_groups_url
        cache_key = ['users', user.id, 'owned_groups_url']
        Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
          groups = user.owned_free_or_trial_groups_with_limit(2)

          next if groups.empty?

          if groups.one?
            ::Gitlab::Routing.url_helpers.group_billings_path(groups.first)
          else
            ::Gitlab::Routing.url_helpers.profile_billings_path
          end
        end
      end
      strong_memoize_attr :owned_groups_url
    end
  end
end
