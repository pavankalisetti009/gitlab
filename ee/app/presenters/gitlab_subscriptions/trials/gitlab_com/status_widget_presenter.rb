# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module GitlabCom
      class StatusWidgetPresenter < Gitlab::View::Presenter::Simple
        include Gitlab::Utils::StrongMemoize
        include Gitlab::Experiment::Dsl

        presents ::Namespace, as: :namespace

        EXPIRED_TRIAL_WIDGET = 'expired_trial_status_widget'
        TIME_FRAME_AFTER_EXPIRATION = 10.days
        private_constant :TIME_FRAME_AFTER_EXPIRATION

        def eligible_for_widget?
          duo_enterprise_status.show? && (eligible_trial_active? || eligible_expired_trial?)
        end

        def attributes
          {
            trial_widget_data_attrs: {
              trial_type: trial_type,
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

        def eligible_trial_active?
          GitlabSubscriptions::Trials.namespace_plan_eligible_for_active?(namespace) &&
            duo_enterprise_trial_add_on_purchase.expires_on > Date.current
        end

        def eligible_expired_trial?
          GitlabSubscriptions::Trials.namespace_plan_eligible?(namespace) &&
            !user_dismissed_widget? &&
            !GitlabSubscriptions::Trials.namespace_with_mid_trial_premium?(
              namespace,
              duo_enterprise_trial_add_on_purchase.started_at
            )
        end

        def duo_enterprise_status
          GitlabSubscriptions::Trials::AddOnStatus.new(
            add_on_purchase: duo_enterprise_trial_add_on_purchase
          )
        end

        def duo_enterprise_trial_add_on_purchase
          GitlabSubscriptions::Trials::DuoEnterprise.any_add_on_purchase_for_namespace(namespace)
        end
        strong_memoize_attr :duo_enterprise_trial_add_on_purchase

        def trial_status
          GitlabSubscriptions::TrialStatus.new(
            duo_enterprise_trial_add_on_purchase.started_at,
            duo_enterprise_trial_add_on_purchase.expires_on
          )
        end
        strong_memoize_attr :trial_status

        def user_dismissed_widget?
          user.dismissed_callout_for_group?(feature_name: EXPIRED_TRIAL_WIDGET, group: namespace)
        end

        def trial_type
          # rubocop:disable Cop/ExperimentsTestCoverage -- covered in ee/spec/presenters/gitlab_subscriptions/trials/gitlab_com/status_widget_presenter_spec.rb
          experiment(:premium_message_during_trial, namespace: namespace, only_assigned: true) do |e|
            e.control { 'ultimate' }
            e.candidate { 'ultimate_with_premium_title' }
          end.run
          # rubocop:enable Cop/ExperimentsTestCoverage
        end
      end
    end
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/presenters/jh/gitlab_subscriptions/trials/status_widget_presenter.rb
GitlabSubscriptions::Trials::GitlabCom::StatusWidgetPresenter.prepend_mod
