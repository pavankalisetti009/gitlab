# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::AutomaticTrialRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.company_form_type' do
    subject { described_class.company_form_type }

    it { is_expected.to eq('registration') }
  end

  describe '.product_interaction' do
    subject { described_class.product_interaction }

    it { is_expected.to eq('SaaS Trial - defaulted') }
  end

  describe '.show_company_form_side_column?' do
    it { is_expected.to be_show_company_form_side_column }
  end
end
