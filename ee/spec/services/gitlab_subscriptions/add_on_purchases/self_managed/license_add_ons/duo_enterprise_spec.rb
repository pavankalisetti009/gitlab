# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::DuoEnterprise,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  describe '#execute' do
    subject(:add_on_license) { described_class.new(restrictions) }

    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let(:restrictions) { { duo_enterprise: { quantity: quantity } } }
    let(:quantity) { 1 }

    describe "#seat_count" do
      it { expect(add_on_license.seat_count).to eq 1 }

      context "with non symbol key hash" do
        let(:restrictions) { { duo_enterprise: { "quantity" => quantity } } }

        it { expect(add_on_license.seat_count).to eq 1 }
      end

      context "with empty restrictions hash" do
        let(:restrictions) { {} }

        it { expect(add_on_license.seat_count).to eq 0 }
      end
    end

    describe "#add_on" do
      it { expect(add_on_license.add_on).to eq add_on }
    end
  end
end
