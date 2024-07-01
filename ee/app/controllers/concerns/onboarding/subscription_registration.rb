# frozen_string_literal: true

module Onboarding
  class SubscriptionRegistration
    TRACKING_LABEL = 'subscription_registration'
    private_constant :TRACKING_LABEL

    # string methods

    def self.tracking_label
      TRACKING_LABEL
    end

    # internalization methods

    def self.welcome_submit_button_text
      _('Continue')
    end

    def self.setup_for_company_label_text
      _('Who will be using this GitLab subscription?')
    end

    # predicate methods

    def self.redirect_to_company_form?
      false
    end

    def self.eligible_for_iterable_trigger?
      false
    end

    def self.show_joining_project?
      true
    end

    def self.show_opt_in_to_email?
      true
    end

    def self.hide_setup_for_company_field?
      false
    end

    def self.pre_parsed_email_opt_in?
      false
    end

    def self.read_from_stored_user_location?
      true
    end

    def self.preserve_stored_location?
      true
    end
  end
end
