# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterprise, feature_category: :subscription_management do
  describe '.add_on_purchase_for_namespace' do
    subject(:add_on_purchase_for_namespace) { described_class.add_on_purchase_for_namespace(namespace) }

    let_it_be(:namespace) { create(:group) }

    context 'when there is a trial add_on_purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial, namespace: namespace)
      end

      it 'returns the add_on_purchase' do
        expect(add_on_purchase_for_namespace).to eq(add_on_purchase)
      end
    end

    context 'when there is an add_on_purchase that is not a trial' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it 'returns nil' do
        expect(add_on_purchase_for_namespace).to be_nil
      end
    end

    context 'when there are no add_on_purchases' do
      it 'returns nil' do
        expect(add_on_purchase_for_namespace).to be_nil
      end
    end
  end
end
