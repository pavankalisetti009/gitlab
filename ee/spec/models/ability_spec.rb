# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ability, feature_category: :system_access do
  describe '.allowed?' do
    context 'with composite_id_service_account_outside_origin_group? check', :request_store do
      let_it_be(:origin_group) { create(:group) }
      let_it_be(:other_group) { create(:group) }
      let_it_be(:service_account) do
        create(:user, :service_account, composite_identity_enforced: true).tap do |user|
          user.user_detail.update!(provisioned_by_group: origin_group)
        end
      end

      let_it_be(:scoped_user) { create(:user) }

      before_all do
        # Add both users as members

        origin_group.add_developer(service_account)
        origin_group.add_developer(scoped_user)
        other_group.add_developer(service_account)
        other_group.add_developer(scoped_user)
      end

      before do
        stub_saas_features(service_accounts_invite_restrictions: true)
        stub_feature_flags(restrict_invites_for_comp_id_service_accounts: true)

        # Set up composite identity (must be in before, not before_all, due to request store)
        ::Gitlab::Auth::Identity.new(service_account).link!(scoped_user)
      end

      it 'returns false when service account is outside origin group hierarchy' do
        expect(described_class.allowed?(service_account, :read_group, other_group)).to be false
      end

      it 'returns true when service account is within origin group hierarchy' do
        expect(described_class.allowed?(service_account, :read_group, origin_group)).to be true
      end

      it 'calls composite_id_service_account_outside_origin_group? during permission check' do
        allow(described_class).to receive(:composite_id_service_account_outside_origin_group?).and_call_original

        described_class.allowed?(service_account, :read_group, other_group)

        expect(described_class).to have_received(:composite_id_service_account_outside_origin_group?)
                                     .with(service_account, other_group)
                                     .at_least(:once)
      end
    end
  end

  describe '.issues_readable_by_user' do
    context 'with IP restrictions' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:user) { create(:user, developer_of: group) }

      let_it_be(:issues) { create_list(:issue, 2, project: project) }

      before_all do
        create(:ip_restriction, group: group, range: '192.168.0.0/24')
      end

      before do
        stub_licensed_features(group_ip_restriction: true)
      end

      it 'returns issues when IP is within the configured range' do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')

        expect(described_class.issues_readable_by_user(issues, user)).to match_array(issues)
      end

      it 'excludes issues when IP is outside the configured range' do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('10.0.1.1')

        expect(described_class.issues_readable_by_user(issues, user)).to be_empty
      end
    end
  end
end
