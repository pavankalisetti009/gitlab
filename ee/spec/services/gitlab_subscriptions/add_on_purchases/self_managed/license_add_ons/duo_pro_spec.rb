# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::DuoPro,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  describe '#execute' do
    subject(:add_on_license) { described_class.new(restrictions) }

    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let(:restrictions) { { code_suggestions_seat_count: 1 } }

    describe "#seat_count" do
      it { expect(add_on_license.seat_count).to eq 1 }

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
