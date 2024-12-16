# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class BaseCreateAddOnService < ::GitlabSubscriptions::Trials::BaseCreateService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        return not_found unless Trials.eligible_namespace?(trial_params[:namespace_id], namespaces_eligible_for_trial)

        super
      end

      private

      def trial_flow
        return not_found if trial_params[:namespace_id].blank?

        existing_namespace_flow
      end

      override :after_lead_success_hook
      def after_lead_success_hook
        track_event('lead_creation_success')

        super
      end

      override :after_lead_error_hook
      def after_lead_error_hook(_result)
        track_event('lead_creation_failure')

        super
      end

      override :after_trial_success_hook
      def after_trial_success_hook(_result)
        track_event('trial_registration_success')

        super
      end

      override :after_trial_error_hook
      def after_trial_error_hook(_result)
        track_event('trial_registration_failure')

        super
      end

      def lead_service_class
        GitlabSubscriptions::Trials::CreateAddOnLeadService
      end

      override :trial_user_params
      def trial_user_params
        super.merge(
          {
            product_interaction: product_interaction,
            preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
            opt_in: user.onboarding_status_email_opt_in
          }
        )
      end

      def product_interaction
        raise NoMethodError, "Subclasses must implement the #{__method__} method"
      end

      def tracking_prefix
        raise NoMethodError, "Subclasses must implement the #{__method__} method"
      end

      def track_event(action)
        action_name = "#{tracking_prefix}_#{action}"

        Gitlab::InternalEvents.track_event(action_name, user: user, namespace: namespace)
      end
    end
  end
end
