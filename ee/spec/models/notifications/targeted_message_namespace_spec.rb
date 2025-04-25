# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessageNamespace, feature_category: :acquisition do
  describe 'associations' do
    it { is_expected.to belong_to(:targeted_message).required }
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    subject { build(:targeted_message_namespace) }

    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:targeted_message_id) }
  end

  describe 'scopes' do
    describe ".by_namespace" do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:namespace_2) { create(:namespace) }
      let_it_be(:targeted_message_namespace) { create(:targeted_message_namespace, namespace: namespace) }
      let_it_be(:targeted_message_namespace_2) { create(:targeted_message_namespace, namespace: namespace_2) }

      it "returns records for the given namespace" do
        expect(described_class.by_namespace(namespace)).to contain_exactly(targeted_message_namespace)
      end
    end
  end
end
