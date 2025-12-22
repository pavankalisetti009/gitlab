# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Notifications::TargetedMessageResolver, feature_category: :acquisition do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group, owners: [user], developers: [developer]) }
  let_it_be(:group_without_message) { create(:group, owners: [user]) }
  let_it_be(:targeted_message) { create(:targeted_message) }
  let_it_be(:targeted_message_namespace) do
    create(:targeted_message_namespace, namespace: group, targeted_message: targeted_message)
  end

  let(:current_user) { user }

  subject(:resolve_targeted_message_data) do
    resolve(described_class, obj: group, ctx: { current_user: current_user })
  end

  describe '#resolve' do
    context 'when user is the owner of the namespace' do
      it 'returns targeted message' do
        expect(resolve_targeted_message_data).to eq([targeted_message])
      end
    end

    context 'when user is not the owner of the namespace' do
      let_it_be(:current_user) { developer }

      it 'returns nil' do
        expect(resolve_targeted_message_data).to be_nil
      end
    end

    context 'when namespace has no targeted message' do
      subject(:resolve_targeted_message_data) do
        resolve(described_class, obj: group_without_message, ctx: { current_user: current_user })
      end

      it 'returns nil' do
        expect(resolve_targeted_message_data).to be_empty
      end
    end
  end
end
