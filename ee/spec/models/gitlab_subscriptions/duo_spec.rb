# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo, feature_category: :"add-on_provisioning" do
  describe '.any_add_on_purchase_for_namespace' do
    subject { described_class.any_add_on_purchase_for_namespace(namespace) }

    let(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let(:expires_on) { 1.year.from_now.to_date }
    let(:namespace) { create(:namespace) }

    let!(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: namespace, expires_on: expires_on)
    end

    it { is_expected.to eq(add_on_purchase) }

    context 'with expired add-on purchase' do
      let(:expires_on) { 1.day.ago.to_date }

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'with different namespace' do
      subject { described_class.any_add_on_purchase_for_namespace("foo") }

      it { is_expected.to be_nil }
    end

    context 'with other duo add-on' do
      let(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'with non Duo add-on' do
      let(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      it { is_expected.to be_nil }
    end
  end
end
