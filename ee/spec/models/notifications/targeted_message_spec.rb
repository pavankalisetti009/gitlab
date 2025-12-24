# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessage, feature_category: :acquisition do
  describe 'validations' do
    subject(:targeted_message) { build(:targeted_message) }

    it { is_expected.to validate_presence_of(:target_type) }

    context 'with targeted_message_namespaces validation' do
      it 'is invalid without any namespaces' do
        targeted_message.targeted_message_namespaces.clear
        expect(targeted_message).not_to be_valid
      end

      it 'is valid with at least one namespace' do
        expect(targeted_message).to be_valid
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:targeted_message_namespaces) }
    it { is_expected.to have_many(:targeted_message_dismissals) }
    it { is_expected.to have_many(:namespaces).through(:targeted_message_namespaces) }

    describe 'dependent destroy' do
      let_it_be(:user) { create(:user) }
      let_it_be(:targeted_message) { create(:targeted_message) }
      let_it_be(:dismissal) do
        create(:targeted_message_dismissal, targeted_message_id: targeted_message.id,
          namespace: targeted_message.namespaces.take, user: user)
      end

      it 'destroys associated targeted_message_namespaces and targeted_message_dismissals when message is destroyed' do
        expect { targeted_message.destroy! }
          .to change { Notifications::TargetedMessageNamespace.count }.by(-1)
          .and change { Notifications::TargetedMessageDismissal.count }.by(-1)
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:target_type) }

    it_behaves_like 'having unique enum values'
  end
end
