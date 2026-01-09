# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::Client, feature_category: :consumables_cost_management do
  subject { described_class }

  it { is_expected.to include_module Gitlab::SubscriptionPortal::Clients::Graphql }
  it { is_expected.to include_module Gitlab::SubscriptionPortal::Clients::Rest }

  describe ".license_checksum_headers" do
    subject(:license_checksum_headers) { described_class.license_checksum_headers }

    context "with the license" do
      it "returns the `X-License-Token` header with the license checksum as value" do
        is_expected.to include({
          "X-License-Token" => License.current.checksum
        })
      end
    end

    context "without license", :without_license do
      it "raises the `No active license` error" do
        expect do
          license_checksum_headers
        end.to raise_error(/No active license/)
      end
    end
  end
end
