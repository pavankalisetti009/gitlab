# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupsFinder, feature_category: :global_search do
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }

    subject(:execute) { described_class.new(user: user).execute }

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has no matching groups' do
      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has direct membership to a group' do
      it 'returns that group' do
        group.add_developer(user)

        expect(execute).to contain_exactly(group)
      end
    end

    context 'when user has membership through a shared group link' do
      let_it_be(:shared_with_group) { create(:group, developers: user) }
      let_it_be_with_reload(:group_group_link) do
        create(:group_group_link, shared_with_group: shared_with_group, shared_group: group)
      end

      it 'returns the direct access group and the shared group' do
        expect(execute).to contain_exactly(shared_with_group, group)
      end

      context 'and the group link is expired' do
        it 'returns only the direct access group' do
          group_group_link.update!(expires_at: 1.day.ago)

          expect(execute).to contain_exactly(shared_with_group)
        end
      end
    end
  end
end
