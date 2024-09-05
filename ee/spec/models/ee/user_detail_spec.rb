# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserDetail, feature_category: :system_access do
  it { is_expected.to belong_to(:provisioned_by_group) }
  it { is_expected.to belong_to(:enterprise_group).inverse_of(:enterprise_user_details) }

  describe 'validations' do
    context 'with support for hash with indifferent access - ind_jsonb' do
      specify do
        user_detail = build(:user_detail, onboarding_status: { 'step_url' => '_string_' })
        user_detail.onboarding_status[:email_opt_in] = true

        expect(user_detail).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.with_enterprise_group' do
      subject(:scope) { described_class.with_enterprise_group }

      let_it_be(:user_detail_with_enterprise_group) { create(:enterprise_user).user_detail }
      let_it_be(:user_details_without_enterprise_group) { create_list(:user_detail, 3, enterprise_group: nil) }

      it 'returns user details with enterprise group' do
        expect(scope).to contain_exactly(
          user_detail_with_enterprise_group
        )
      end
    end
  end

  describe '#provisioned_by_group?' do
    let(:user) { create(:user, provisioned_by_group: build(:group)) }

    subject { user.user_detail.provisioned_by_group? }

    it 'returns true when user is provisioned by group' do
      expect(subject).to eq(true)
    end

    it 'returns true when user is provisioned by group' do
      user.user_detail.update!(provisioned_by_group: nil)

      expect(subject).to eq(false)
    end
  end

  context 'with loose foreign key on user_details.provisioned_by_group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:user_detail, provisioned_by_group: parent) }
    end
  end

  context 'with loose foreign key on user_details.enterprise_group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:user_detail, enterprise_group: parent) }
    end
  end
end
