# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions, :saas, feature_category: :subscription_management do
  describe '.find_eligible_namespace' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, owners: user) }

    context 'when the namespace ID is blank' do
      it 'returns nil' do
        namespace = described_class.find_eligible_namespace(user: user, namespace_id: '', plan_id: 'plan-id')

        expect(namespace).to be_nil
      end
    end

    context 'when the namespace is not eligible for the purchase' do
      it 'returns nil' do
        allow_next_instance_of(
          GitlabSubscriptions::PurchaseEligibleNamespacesFinder,
          user: user, namespace_id: group.id, plan_id: 'plan-id'
        ) do |finder|
          allow(finder).to receive(:execute).and_return(Namespace.none)
        end

        namespace = described_class.find_eligible_namespace(
          user: user,
          namespace_id: group.id,
          plan_id: 'plan-id'
        )

        expect(namespace).to be_nil
      end
    end

    context 'when the namespace is eligible for the purchase' do
      it 'returns the namespace' do
        allow_next_instance_of(
          GitlabSubscriptions::PurchaseEligibleNamespacesFinder,
          user: user, namespace_id: group.id, plan_id: 'plan-id'
        ) do |finder|
          allow(finder).to receive(:execute).and_return([group])
        end

        namespace = described_class.find_eligible_namespace(user: user, namespace_id: group.id, plan_id: 'plan-id')

        expect(namespace).to eq group
      end
    end
  end
end
