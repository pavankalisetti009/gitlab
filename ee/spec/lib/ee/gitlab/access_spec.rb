# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Access, feature_category: :permissions do
  let_it_be_with_reload(:member) { create(:group_member, :developer) }
  let_it_be(:member_role) { create(:member_role, :developer, name: 'IM') }

  describe '#human_access' do
    it 'returns correct name for default role' do
      expect(member.human_access).to eq('Developer')
    end

    it 'returns correct name for custom role' do
      member.update!(member_role: member_role)

      expect(member.human_access).to eq('IM')
    end
  end

  describe '#human_access_labeled' do
    it 'returns correct label for default role' do
      expect(member.human_access_labeled).to eq('Default role: Developer')
    end

    it 'returns correct label for custom role' do
      member.update!(member_role: member_role)

      expect(member.human_access_labeled).to eq('Custom role: IM')
    end
  end
end
