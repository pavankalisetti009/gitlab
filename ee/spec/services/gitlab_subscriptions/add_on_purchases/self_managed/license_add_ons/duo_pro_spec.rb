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
          "duo_pro" => [{ "quantity" => 1 }, { "quantity" => 2 }]
        }
      }
    end

    describe "#seat_count" do
      it { expect(add_on_license.seat_count).to eq 3 }

      context "with mixed hash key types" do
        let(:restrictions) do
          {
            add_on_products: {
              "duo_pro" => [{ quantity: 1 }, { "quantity" => 2 }]
            }
          }
        end

        it { expect(add_on_license.seat_count).to eq 3 }
      end

      context "with empty restrictions hash" do
        let(:restrictions) { {} }

        it { expect(add_on_license.seat_count).to eq 0 }
      end

      context "with empty duo pro info" do
        let(:restrictions) do
          {
            add_on_products: {
              "duo_enterprise" => [{ "quantity" => 2 }]
            }
          }
        end

        it { expect(add_on_license.seat_count).to eq 0 }
      end

      context "with an empty quantity key in the duo pro info" do
        let(:restrictions) do
          {
            add_on_products: {
              "duo_pro" => [{ "started_on" => '2024-08-01' }]
            }
          }
        end

        it { expect(add_on_license.seat_count).to eq 0 }
      end
    end

    describe "#add_on" do
      it { expect(add_on_license.add_on).to eq add_on }
    end
  end
end
