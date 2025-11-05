# frozen_string_literal: true

module GitlabSubscriptions
  class TierBadgePresenter < Gitlab::View::Presenter::Simple
    presents ::Namespace, as: :namespace

    def attributes
      return {} unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) && namespace.present? &&
        namespace.persisted? && namespace.free_plan? && Ability.allowed?(@subject, :edit_billing, namespace)

      {
        tier_badge_href: group_billings_path(namespace, source: "sidebar-free-tier-highlight")
      }
    end
  end
end
