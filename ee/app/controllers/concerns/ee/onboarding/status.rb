# frozen_string_literal: true

module EE
  module Onboarding
    module Status
      REGISTRATION_KLASSES = {
        ::Onboarding::REGISTRATION_TYPE[:free] => ::Onboarding::FreeRegistration,
        ::Onboarding::REGISTRATION_TYPE[:trial] => ::Onboarding::TrialRegistration,
        ::Onboarding::REGISTRATION_TYPE[:invite] => ::Onboarding::InviteRegistration,
        ::Onboarding::REGISTRATION_TYPE[:subscription] => ::Onboarding::SubscriptionRegistration
      }.freeze

      GLM_PARAMS = [:glm_source, :glm_content].freeze

      attr_reader :registration_type

      # string delegations
      delegate :tracking_label, :product_interaction, to: :registration_type
      # translation delegations
      delegate :setup_for_company_label_text, to: :registration_type
      delegate :setup_for_company_help_text, to: :registration_type
      # predicate delegations
      delegate :redirect_to_company_form?, :eligible_for_iterable_trigger?, to: :registration_type
      delegate :show_opt_in_to_email?, :show_joining_project?, :apply_trial?, to: :registration_type
      delegate :hide_setup_for_company_field?, :pre_parsed_email_opt_in?, to: :registration_type
      delegate :read_from_stored_user_location?, :preserve_stored_location?, to: :registration_type

      module ClassMethods
        extend ::Gitlab::Utils::Override

        def glm_tracking_params(params)
          params.permit(*GLM_PARAMS)
        end

        override :registration_path_params
        def registration_path_params(params:, extra_params: {})
          return super unless ::Onboarding.enabled?

          glm_tracking_params(params).to_h.merge(extra_params)
        end
      end

      def self.prepended(base)
        base.singleton_class.prepend(ClassMethods)
      end

      def initialize(*)
        super

        @registration_type = calculate_registration_type_klass
      end

      def welcome_submit_button_text
        base_value = registration_type.welcome_submit_button_text

        return base_value if registration_type.ignore_oauth_in_welcome_submit_text?
        return _('Get started!') if oauth?

        # free, trial if not in oauth
        base_value
      end

      def continue_full_onboarding?
        registration_type.continue_full_onboarding? && !oauth? && ::Onboarding.enabled?
      end

      def joining_a_project?
        ::Gitlab::Utils.to_boolean(params[:joining_project], default: false)
      end

      def convert_to_automatic_trial?
        return false unless registration_type.convert_to_automatic_trial?

        setup_for_company?
      end

      def preregistration_tracking_label
        # Trial registrations do not call this right now, so we'll omit it here from consideration.
        return ::Onboarding::InviteRegistration.tracking_label if params[:invite_email]
        return ::Onboarding::SubscriptionRegistration.tracking_label if subscription_from_stored_location?

        ::Onboarding::FreeRegistration.tracking_label
      end

      def setup_for_company?
        ::Gitlab::Utils.to_boolean(params.dig(:user, :setup_for_company), default: false)
      end

      def company_lead_product_interaction
        if initial_trial?
          ::Onboarding::TrialRegistration.product_interaction
        else
          # Due to this only being called in an area where only trials reach,
          # we can assume and not check for free/invite/subscription/etc here.
          'SaaS Trial - defaulted'
        end
      end

      def initial_trial?
        user.onboarding_status_initial_registration_type == ::Onboarding::REGISTRATION_TYPE[:trial]
      end

      def stored_user_location
        # side effect free look at devise store_location_for(:user)
        session['user_return_to']
      end

      private

      attr_reader :params, :session

      def calculate_registration_type_klass
        REGISTRATION_KLASSES.fetch(user&.onboarding_status_registration_type, ::Onboarding::FreeRegistration)
      end

      def oauth?
        # During authorization for oauth, we want to allow it to finish.
        return false unless base_stored_user_location_path.present?

        base_stored_user_location_path == ::Gitlab::Routing.url_helpers.oauth_authorization_path
      end

      def subscription_from_stored_location?
        base_stored_user_location_path == ::Gitlab::Routing.url_helpers.new_subscriptions_path
      end

      def base_stored_user_location_path
        return unless stored_user_location

        URI.parse(stored_user_location).path
      end
    end
  end
end
