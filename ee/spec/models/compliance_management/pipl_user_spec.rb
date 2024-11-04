# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::PiplUser,
  type: :model,
  feature_category: :compliance_management do
  it { is_expected.to belong_to(:user).required(true) }

  it { is_expected.to validate_presence_of(:last_access_from_pipl_country_at) }

  describe '.for_user' do
    let_it_be(:pipl_user) { create(:pipl_user) }
    let_it_be(:other_user) { create(:user) }
    let(:user) { pipl_user }

    subject(:for_user) { described_class.for_user(user) }

    it { is_expected.to eq(pipl_user) }

    context 'when there is no pipl user' do
      let(:user) { other_user }

      it { is_expected.to be_nil }
    end
  end

  describe '.untrack_access!' do
    let!(:pipl_user) { create(:pipl_user) }

    subject(:untrack_access) { described_class.untrack_access!(user) }

    context 'when the params is not a user instance' do
      let!(:user) { pipl_user }

      it 'does not untrack PIPL access' do
        expect { untrack_access }.to not_change { ComplianceManagement::PiplUser.count }
      end
    end

    context 'when the param is a user instance' do
      let!(:user) { pipl_user.user }

      subject(:untrack_access) { described_class.untrack_access!(user) }

      it 'deletes the record' do
        expect { untrack_access }.to change { ComplianceManagement::PiplUser.count }.by(-1)
        expect { user.reload }.not_to raise_error
      end
    end
  end

  describe '.track_access' do
    let!(:user) { create(:user) }

    subject(:track_access) { described_class.track_access(user) }

    it 'tracks PIPL access' do
      expect { track_access }.to change { ComplianceManagement::PiplUser.count }.by(1)
      expect(user.pipl_user.present?).to be(true)
    end
  end

  describe '#recently_tracked?', :freeze_time do
    let_it_be_with_reload(:pipl_user) { create(:pipl_user) }

    subject(:recently_tracked) { pipl_user.recently_tracked? }

    it { is_expected.to be(true) }

    context 'when the user was not tracked withing the past 24 hours' do
      before_all do
        pipl_user.update!(last_access_from_pipl_country_at: 25.hours.ago)
      end

      it { is_expected.to be(false) }
    end
  end
end
