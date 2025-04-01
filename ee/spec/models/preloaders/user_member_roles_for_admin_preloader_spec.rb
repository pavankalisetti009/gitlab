# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::UserMemberRolesForAdminPreloader, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  subject(:result) { described_class.new(user: user).execute }

  shared_examples 'custom roles' do |ability|
    let_it_be(:member_role) { create(:admin_member_role, ability, user: user) }

    let(:expected_abilities) { [ability].compact }

    context 'when custom_roles license is enabled' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when ability is enabled' do
        it 'returns all allowed abilities' do
          expect(result).to eq({ admin: expected_abilities })
        end
      end

      context 'when ability is disabled' do
        before do
          stub_feature_flag_definition("custom_ability_#{ability}")
          stub_feature_flags("custom_ability_#{ability}" => false)
        end

        it { expect(result).to eq({ admin: [] }) }
      end
    end
  end

  MemberRole.all_customizable_admin_permission_keys.each do |ability|
    it_behaves_like 'custom roles', ability
  end
end
