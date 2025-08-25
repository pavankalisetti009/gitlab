# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::CategoryPolicy, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:category) { create(:security_category, namespace: root_group) }

  subject { described_class.new(user, category) }

  context 'when user is maintainer of root group' do
    before_all do
      root_group.add_maintainer(user)
    end

    it { is_expected.to be_allowed(:read_security_category) }
  end

  context 'when user is maintainer of subgroup' do
    before_all do
      group.add_maintainer(user)
    end

    it { is_expected.to be_disallowed(:read_security_category) }
  end

  context 'when user has developer access to root_group' do
    before_all do
      root_group.add_developer(user)
    end

    it { is_expected.to be_disallowed(:read_security_category) }
  end

  context 'when user has no access to any group' do
    subject { described_class.new(user, category) }

    it { is_expected.to be_disallowed(:read_security_category) }
  end

  context 'when user is owner of subgroup' do
    before_all do
      group.add_owner(user)
    end

    it { is_expected.to be_disallowed(:read_security_category) }
  end
end
