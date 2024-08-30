# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::Member, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:parent_groups) { [] }
  let_it_be(:group_member) { create(:group_member, :developer, group: group) }

  describe 'initialization' do
    it 'creates a new instance correctly' do
      member = described_class.new(group_member, group, parent_groups)

      aggregate_failures do
        expect(member.name).to eq(group_member.user.name)
        expect(member.username).to eq(group_member.user.username)
        expect(member.role).to eq('Developer')
        expect(member.membership_type).to eq('direct')
        expect { member.unknown }.to raise_error(NoMethodError)
      end
    end
  end
end
