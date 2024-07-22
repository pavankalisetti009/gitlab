# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::GroupsFinder, feature_category: :groups_and_projects do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { organization: organization } }
  let(:finder) { described_class.new(current_user, params) }

  subject(:organization_groups) { finder.execute.to_a }

  describe '#by_saml_sso_session' do
    let_it_be(:root_group1) do
      create(:group, organization: organization, saml_provider: create(:saml_provider), developers: current_user)
    end

    let_it_be(:root_group2) do
      create(:group, organization: organization, saml_provider: create(:saml_provider), developers: current_user)
    end

    let_it_be(:private_root_group) do
      create(:group, :private,
        organization: organization, saml_provider: create(:saml_provider), developers: current_user)
    end

    let_it_be(:subgroup1) { create(:group, organization: organization, parent: root_group1) }
    let_it_be(:subgroup2) { create(:group, organization: organization, parent: root_group2) }
    let_it_be(:private_subgroup) { create(:group, :private, organization: organization, parent: private_root_group) }
    let_it_be(:all_groups) { [root_group1, subgroup1, root_group2, subgroup2, private_root_group, private_subgroup] }

    before_all do
      [root_group1, private_root_group].each do |root_group|
        create(:group_saml_identity, saml_provider: root_group.saml_provider, user: current_user)
      end
    end

    context 'when the current user is nil' do
      let_it_be(:current_user) { nil }

      it 'includes public SAML groups' do
        expect(organization_groups).to contain_exactly(root_group1, subgroup1, root_group2, subgroup2)
      end
    end

    shared_examples 'includes inactive session SAML groups' do
      specify do
        expect(organization_groups).to match_array(all_groups)
      end
    end

    context 'when the current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'includes inactive session SAML groups'
    end

    context 'when the current user has no active SAML sessions' do
      it 'filters out the SAML member groups' do
        expect(organization_groups).to contain_exactly(root_group2, subgroup2)
      end
    end

    context 'when filter_expired_saml_session_groups param is false' do
      let(:params) { { organization: organization, filter_expired_saml_session_groups: false } }

      it_behaves_like 'includes inactive session SAML groups'
    end

    context 'when the current user has active SAML sessions' do
      before do
        active_saml_sessions = { root_group1.saml_provider.id => Time.current,
                                 private_root_group.saml_provider.id => Time.current }
        allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
      end

      it_behaves_like 'includes inactive session SAML groups'
    end
  end
end
