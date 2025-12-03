# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ability, feature_category: :system_access do
  describe '.composite_id_service_account_outside_origin_group?' do
    let_it_be(:origin_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: origin_group) }
    let_it_be(:other_group) { create(:group) }
    let_it_be(:deeply_nested_subgroup) { create(:group, parent: subgroup) }
    let_it_be(:other_subgroup) { create(:group, parent: other_group) }
    let_it_be(:project) { create(:project) }

    let_it_be_with_reload(:service_account) do
      create(:user, :service_account, composite_identity_enforced: true).tap do |user|
        user.user_detail.update!(provisioned_by_group: origin_group)
      end
    end

    let_it_be(:non_composite_service_account) do
      create(:user, :service_account, composite_identity_enforced: false)
    end

    let_it_be(:instance_level_service_account) do
      create(:user, :service_account, composite_identity_enforced: true,
        user_detail: create(:user_detail, provisioned_by_group: nil))
    end

    subject(:result) { described_class.composite_id_service_account_outside_origin_group?(user, subject_group) }

    context 'when SaaS feature is not available' do
      let(:user) { service_account }
      let(:subject_group) { other_group }

      before do
        stub_saas_features(service_accounts_invite_restrictions: false)
      end

      it 'returns false' do
        expect(result).to be false
      end
    end

    context 'when SaaS feature is available' do
      before do
        stub_saas_features(service_accounts_invite_restrictions: true)
      end

      context 'when feature flag is disabled' do
        let(:user) { service_account }
        let(:subject_group) { other_group }

        before do
          stub_feature_flags(restrict_invites_for_comp_id_service_accounts: false)
        end

        it 'returns false' do
          expect(result).to be false
        end
      end

      context 'when user does not have composite_identity_enforced' do
        let(:user) { non_composite_service_account }
        let(:subject_group) { other_group }

        it 'returns false' do
          expect(result).to be false
        end
      end

      context 'when user is nil' do
        let(:user) { nil }
        let(:subject_group) { other_group }

        it 'returns false' do
          expect(result).to be false
        end
      end

      context 'when user does not have provisioned_by_group_id (instance-level SA)' do
        let(:user) { instance_level_service_account }
        let(:subject_group) { other_group }

        it 'returns false to allow instance-level SAs' do
          expect(result).to be false
        end
      end

      context 'when subject is not a Group' do
        let(:user) { service_account }
        let(:subject_group) { project }

        it 'returns false' do
          expect(result).to be false
        end
      end

      context 'when subject is the origin group' do
        let(:user) { service_account }
        let(:subject_group) { origin_group }

        it 'returns false' do
          expect(result).to be false
        end
      end

      context 'when subject is a subgroup of the origin group' do
        let(:user) { service_account }
        let(:subject_group) { subgroup }

        it 'returns false' do
          expect(result).to be false
        end
      end

      context 'when subject is a deeply nested subgroup of the origin group' do
        let(:user) { service_account }
        let(:subject_group) { deeply_nested_subgroup }

        it 'returns false' do
          expect(result).to be false
        end
      end

      context 'when subject is a parent of the origin group' do
        # while we don't allow creating group-level SAs in subgroups currently,
        # it is something we will expand very soon.
        # Therefore, this test clarifies current implementation behaviour.
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:child_origin_group) { create(:group, parent: parent_group) }

        let_it_be_with_reload(:child_service_account) do
          create(:user, :service_account, composite_identity_enforced: true,
            user_detail: create(:user_detail, provisioned_by_group: child_origin_group))
        end

        let(:user) { child_service_account }
        let(:subject_group) { parent_group }

        it 'returns true' do
          expect(result).to be true
        end
      end

      context 'when subject is outside the origin group hierarchy' do
        let(:user) { service_account }
        let(:subject_group) { other_group }

        it 'returns true' do
          expect(result).to be true
        end
      end

      context 'when subject is a subgroup of another group' do
        let(:user) { service_account }
        let(:subject_group) { other_subgroup }

        it 'returns true' do
          expect(result).to be true
        end
      end
    end
  end
end
