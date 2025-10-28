# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::AutomaticTrialRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.product_interaction' do
    subject { described_class.product_interaction }

    it { is_expected.to eq('SaaS Trial - defaulted') }
  end

  describe '.show_company_form_footer?' do
    subject { described_class.show_company_form_footer? }

    it { is_expected.to be(true) }
  end

  describe '.show_company_form_side_column?' do
    it { is_expected.to be_show_company_form_side_column }
  end

  describe '.new_registration_design?' do
    it { is_expected.not_to be_new_registration_design }
  end

  describe '.exclude_from_first_orders_experiments?' do
    it { is_expected.to be_exclude_from_first_orders_experiments }
  end
end
