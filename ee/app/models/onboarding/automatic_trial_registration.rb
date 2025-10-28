# frozen_string_literal: true

module Onboarding
  class AutomaticTrialRegistration < TrialRegistration
    extend ::Gitlab::Utils::Override

    # string methods

    override :product_interaction
    def self.product_interaction
      'SaaS Trial - defaulted'
    end

    # predicate methods

    override :show_company_form_side_column?
    def self.show_company_form_side_column?
      true
    end

    override :show_company_form_footer?
    def self.show_company_form_footer?
      true
    end

    override :new_registration_design?
    def self.new_registration_design?
      false
    end

    def self.exclude_from_first_orders_experiments?
      true
    end
  end
end
