# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScimIdentity, feature_category: :system_access do
  describe 'relations' do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }

    context 'with existing user' do
      before do
        create(:scim_identity, user: user, extern_uid: user.email, group: nil)
      end

      it 'returns false for a duplicate identity with the same extern_uid' do
        identity = user.instance_scim_identities.build(extern_uid: user.email)

        expect(identity.validate).to eq(false)
      end
    end
  end

  describe '.with_extern_uid' do
    it 'finds identity regardless of case' do
      user = create(:user)

      identity = user.instance_scim_identities.create!(extern_uid: user.email)

      expect(described_class.with_extern_uid(user.email.upcase).first).to eq identity
    end
  end

  describe '.for_instance' do
    it 'finds identities not associated with a group' do
      _group_identity = create(:scim_identity, group: create(:group))
      instance_identity = create(:scim_identity, group: nil)

      expect(described_class.for_instance).to match_array(
        [instance_identity]
      )
    end
  end
end
