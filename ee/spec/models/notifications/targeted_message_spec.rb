# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessage, feature_category: :acquisition do
  describe 'validations' do
    subject { build(:targeted_message) }

    it { is_expected.to validate_presence_of(:target_type) }
    it { is_expected.to validate_presence_of(:targeted_message_namespaces) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:targeted_message_namespaces) }
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
