# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::Base,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  describe '#execute' do
    subject(:add_on_license) { dummy_add_on_license_class.new(restrictions) }

    let(:add_on_license_base) { described_class.new(restrictions) }
    let!(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }

    let(:dummy_add_on_license_class) do
      seat_count_on_license = seat_count

      Class.new(described_class) do
        define_method :seat_count_on_license do
          seat_count_on_license
        end

        def name
          :code_suggestions
        end
      end
    end

    let(:restrictions) { { seat_count: seat_count } }
    let(:seat_count) { 1 }

    describe "#seat_count" do
      it { expect { add_on_license_base.seat_count }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license.seat_count).to eq 1 }

      context "without restrictions" do
        let(:restrictions) { nil }

        it { expect(add_on_license.seat_count).to eq 0 }
      end
    end

    describe "#active?" do
      it { expect { add_on_license_base.seat_count }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license).to be_active }

      context "with seat count zero" do
        let(:seat_count) { 0 }

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
