# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::DuoPro,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  describe '#execute' do
    subject(:add_on_license) { described_class.new(restrictions) }

    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let(:restrictions) do
      {
        add_on_products: {
          "duo_pro" => [{ "quantity" => 1 }]
        }
      }
    end

    describe "#quantity" do
      include_examples "license add-on attributes", add_on_name: "duo_pro"
    end

    describe "#add_on" do
      it { expect(add_on_license.add_on).to eq add_on }
    end
  end
end
