# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupsFinder, feature_category: :groups_and_projects do
  include AdminModeHelper

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group_with_wiki) { create(:group, :wiki_repo) }
    let_it_be(:group_without_wiki) { create(:group) }

    subject(:execute) { described_class.new(user, params).execute }

    before_all do
      group_with_wiki.add_developer(user)
      group_without_wiki.add_developer(user)
    end

    context 'when repository storage name is given' do
      let(:params) { { repository_storage: group_with_wiki.repository_storage } }

      it 'filters by the repository storage name' do
        expect(subject).to eq([group_with_wiki])
      end
    end

    context 'when repository storage name is not given' do
      let(:params) { {} }

      it 'returns all groups' do
        expect(subject).to match_array([group_with_wiki, group_without_wiki])
      end
    end

    it_behaves_like 'groups finder with SAML session filtering' do
      let(:finder) { described_class.new(current_user, params) }
    end

    context 'when user has custom admin role with read_admin_groups permission' do
      let_it_be(:role) { create(:admin_member_role, :read_admin_groups, user: user) }

      let_it_be(:authorized_groups) { [group_with_wiki, group_without_wiki] }
      let_it_be(:unauthorized_group) { create(:group, :private) } # group the user is not a member of
      let_it_be(:internal_group) { create(:group, :internal) }
      let_it_be(:public_group) { create(:group, :public) }

      let(:params) { {} }

      before do
        stub_licensed_features(custom_roles: true)
        enable_admin_mode!(user)
      end

      it 'returns all groups' do
        expect(execute).to match_array([*authorized_groups, unauthorized_group, internal_group, public_group])
      end
    end
  end
end
