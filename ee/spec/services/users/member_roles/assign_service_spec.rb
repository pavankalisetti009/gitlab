# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::MemberRoles::AssignService, feature_category: :permissions do
  let_it_be(:member_role) { create(:member_role, :admin) }
  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:current_user) { create(:admin) }

  let(:params) { { user: user, member_role: member_role } }

  subject(:assign_member_role) { described_class.new(current_user, params).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  context 'when current user is not an admin', :enable_admin_mode do
    before do
      current_user.update!(admin: false)
    end

    it 'returns an error' do
      expect(assign_member_role).to be_error
    end
  end

  context 'when current user is an admin', :enable_admin_mode do
    context 'when custom_ability_read_admin_dashboard FF is disabled' do
      before do
        stub_feature_flags(custom_ability_read_admin_dashboard: false)
      end

      it 'returns an error' do
        expect(assign_member_role).to be_error
      end
    end

    context 'when custom_ability_read_admin_dashboard FF is enabled' do
      it 'creates a new user member role relation' do
        expect { assign_member_role }.to change { Users::UserMemberRole.count }.by(1)
      end

      it 'returns success' do
        expect(assign_member_role).to be_success
      end
    end
  end
end
