# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class StatusWidgetPresenter < Gitlab::View::Presenter::Simple
      include Gitlab::Utils::StrongMemoize

      presents ::Namespace, as: :namespace

      EXPIRED_TRIAL_WIDGET = 'expired_trial_status_widget'
      TIME_FRAME_AFTER_EXPIRATION = 10.days
      private_constant :TIME_FRAME_AFTER_EXPIRATION

      def eligible_for_widget?
        eligible_trial_active? || eligible_expired_trial?
      end

      def attributes
        {
          trial_widget_data_attrs: {
            trial_type: determine_trial_type,
            trial_days_used: trial_status.days_used,
            days_remaining: trial_status.days_remaining,
            percentage_complete: trial_status.percentage_complete,
            group_id: namespace.id,
            trial_discover_page_path: group_discover_path(namespace),
            purchase_now_url: group_billings_path(namespace),
            feature_id: EXPIRED_TRIAL_WIDGET,
            dismiss_endpoint: group_callouts_path
          }
        }
      end

      private

      # CDot considers trials on the current day expired. However, in the GitLab
      # codebase, the current day is still regarded as active. This is the fixing
      # for the trial widget. Globally, it should be addressed here:
      # https://gitlab.com/gitlab-org/gitlab/-/issues/502449
      def eligible_trial_active?
        GitlabSubscriptions::Trials.namespace_plan_eligible_for_active?(namespace) &&
          namespace.trial_starts_on &&
          namespace.trial_ends_on &&
          namespace.trial_ends_on > Date.current
      end

      def eligible_expired_trial?
        GitlabSubscriptions::Trials.namespace_plan_eligible?(namespace) &&
          namespace.trial_starts_on &&
          namespace.trial_ends_on &&
          namespace.trial_ends_on > TIME_FRAME_AFTER_EXPIRATION.ago &&
          !user_dismissed_widget?
      end

      def determine_trial_type
        if duo_enterprise_status.show?
          'ultimate'
        else
          'legacy_ultimate'
        end
      end

      def duo_enterprise_status
        GitlabSubscriptions::Trials::AddOnStatus.new(
          add_on_purchase: duo_enterprise_trial_add_on_purchase
        )
      end
      strong_memoize_attr :duo_enterprise_status

      def duo_enterprise_trial_add_on_purchase
        GitlabSubscriptions::Trials::DuoEnterprise.any_add_on_purchase_for_namespace(namespace)
      end
      strong_memoize_attr :duo_enterprise_trial_add_on_purchase

      def trial_status
        @trial_status ||= GitlabSubscriptions::TrialStatus.new(namespace.trial_starts_on, namespace.trial_ends_on)
      end

      def user_dismissed_widget?
        user.dismissed_callout_for_group?(feature_name: EXPIRED_TRIAL_WIDGET, group: namespace)
      end
    end
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/presenters/jh/gitlab_subscriptions/trials/status_widget_presenter.rb
GitlabSubscriptions::Trials::StatusWidgetPresenter.prepend_mod
