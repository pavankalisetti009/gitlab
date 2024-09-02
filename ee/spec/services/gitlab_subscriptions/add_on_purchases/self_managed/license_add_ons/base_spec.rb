# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::Base,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  describe '#execute' do
    subject(:add_on_license) { dummy_add_on_license_class.new(restrictions) }

    let(:add_on_license_base) { described_class.new(restrictions) }
    let!(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }

    let(:dummy_add_on_license_class) do
      Class.new(described_class) do
        def name
          :code_suggestions
        end

        def name_in_license
          :duo_pro
        end
      end
    end

    let(:restrictions) do
      start_date = Date.current

      {
        add_on_products: {
          "duo_pro" => [
            {
              "quantity" => quantity,
              "started_on" => start_date.to_s,
              "expires_on" => (start_date + 1.year).to_s,
              "purchase_xid" => "C-0000001",
              "trial" => false
            }
          ]
        }
      }
    end

    let(:quantity) { 1 }

    describe "#quantity" do
      it { expect { add_on_license_base.quantity }.to raise_error described_class::MethodNotImplementedError }

      include_examples "license add-on attributes", add_on_name: "duo_pro"
    end

    describe "#active?" do
      it { expect { add_on_license_base.active? }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license).to be_active }

      context "with quantity zero" do
        let(:quantity) { 0 }

        it { expect(add_on_license).not_to be_active }
      end
    end

    describe "#add_on" do
      it { expect { add_on_license_base.add_on }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license.add_on).to eq add_on }

      context "without existing add-on" do
        let(:add_on) { nil }

        it "creates add-on" do
          expect { add_on_license.add_on }.to change { GitlabSubscriptions::AddOn.count }.from(0).to(1)
          expect(GitlabSubscriptions::AddOn.first).to be_code_suggestions
        end
      end
    end
  end
end
