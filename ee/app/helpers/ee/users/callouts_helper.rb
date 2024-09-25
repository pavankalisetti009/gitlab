# frozen_string_literal: true

module EE
  module Users
    module CalloutsHelper
      extend ::Gitlab::Utils::Override

      TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK = 'two_factor_auth_recovery_settings_check'
      ACTIVE_USER_COUNT_THRESHOLD = 'active_user_count_threshold'
      GEO_ENABLE_HASHED_STORAGE = 'geo_enable_hashed_storage'
      GEO_MIGRATE_HASHED_STORAGE = 'geo_migrate_hashed_storage'
      ULTIMATE_TRIAL = 'ultimate_trial'
      NEW_USER_SIGNUPS_CAP_REACHED = 'new_user_signups_cap_reached'
      PERSONAL_ACCESS_TOKEN_EXPIRY = 'personal_access_token_expiry'
      PROFILE_PERSONAL_ACCESS_TOKEN_EXPIRY = 'profile_personal_access_token_expiry'
      JOINING_A_PROJECT_ALERT = 'joining_a_project_alert'
      DUO_FREE_ACCESS_ENDING_BANNER = 'duo_free_access_ending_banner'

      override :render_dashboard_ultimate_trial
      def render_dashboard_ultimate_trial(user)
        return unless show_ultimate_trial?(user, ULTIMATE_TRIAL) &&
          user_default_dashboard?(user) &&
          !user.owns_paid_namespace? &&
          user.owns_group_without_trial?

        if ::Feature.enabled?(:duo_enterprise_trials, user)
          render 'shared/ultimate_with_enterprise_trial_callout_content'
        else
          render 'shared/ultimate_trial_callout_content'
        end
      end

      def render_two_factor_auth_recovery_settings_check
        return unless current_user &&
          ::Gitlab.com? &&
          current_user.two_factor_otp_enabled? &&
          !user_dismissed?(TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK, 3.months.ago)

        render 'shared/two_factor_auth_recovery_settings_check'
      end

      def show_new_user_signups_cap_reached?
        return false unless current_user&.can_admin_all_resources?
        return false if user_dismissed?(NEW_USER_SIGNUPS_CAP_REACHED)

        new_user_signups_cap = ::Gitlab::CurrentSettings.current_application_settings.new_user_signups_cap
        return false if new_user_signups_cap.nil?

        new_user_signups_cap.to_i <= ::User.billable.count
      end

      override :dismiss_two_factor_auth_recovery_settings_check
      def dismiss_two_factor_auth_recovery_settings_check
        ::Users::DismissCalloutService.new(
          container: nil, current_user: current_user, params: { feature_name: TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK }
        ).execute
      end

      def show_joining_a_project_alert?
        return false unless cookies[:signup_with_joining_a_project]
        return false unless ::Gitlab::Saas.feature_available?(:onboarding)

        !user_dismissed?(JOINING_A_PROJECT_ALERT)
      end

      def show_duo_free_access_ending_banner?(group)
        return false unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        return false unless ::Feature.enabled?(:duo_free_access_ending_banner, group)
        return false unless can?(current_user, :owner_access, group)
        return false unless group.paid? && GitlabSubscriptions::Duo.no_add_on_purchase_for_namespace?(group)

        !user_dismissed?(DUO_FREE_ACCESS_ENDING_BANNER)
      end

      override :show_transition_to_jihu_callout?
      def show_transition_to_jihu_callout?
        !gitlab_com_subscription? && !has_active_license? && super
      end

      private

      override :dismissed_callout?
      def dismissed_callout?(object, query)
        return super if object.is_a?(Project)

        current_user.dismissed_callout_for_group?(group: object, **query)
      end

      def hashed_storage_enabled?
        ::Gitlab::CurrentSettings.current_application_settings.hashed_storage_enabled
      end

      def show_ultimate_trial?(user, callout = ULTIMATE_TRIAL)
        return false unless user
        return false unless show_ultimate_trial_suitable_env?
        return false if user_dismissed?(callout)

        true
      end

      def show_ultimate_trial_suitable_env?
        ::Gitlab.com? && !::Gitlab::Database.read_only?
      end
    end
  end
end
