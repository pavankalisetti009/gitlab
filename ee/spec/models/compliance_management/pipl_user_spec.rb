# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::PiplUser,
  type: :model,
  feature_category: :compliance_management do
  it { is_expected.to belong_to(:user).required(true) }

  it { is_expected.to validate_presence_of(:last_access_from_pipl_country_at) }

  describe "scopes" do
    describe '.days_from_initial_pipl_email', time_travel_to: '2024-10-07 10:32:45.000000' do
      subject(:scope) { described_class.days_from_initial_pipl_email(*days) }

      # time_travel_to doesn't work with before_all and didn't want to use before to
      # avoid bad performance
      let!(:pipl_users) do
        create(:pipl_user, initial_email_sent_at: Time.current)
        create(:pipl_user, initial_email_sent_at: Time.current - 30.days)
        create(:pipl_user, initial_email_sent_at: Time.current - 90.days)
      end

      let(:days) { [0.days, 30.days, 90.days] }

      it 'returns all the user_details' do
        result = scope

        expect(result.count).to eq(3)
      end

      context 'when days matches only a part of the details' do
        let(:days) { [30.days] }

        it 'returns only the matched results' do
          result = scope
          expect(result.count).to eq(1)
          expect(result.first.initial_email_sent_at).to eq(Time.current - 30.days)
        end
      end

      context 'when days does not match any records' do
        let(:days) { [10.days] }

        it 'does not return any results' do
          result = scope

          expect(result.count).to eq(0)
        end
      end
    end

    describe '.with_due_notifications', time_travel_to: '2024-10-07 10:32:45.000000' do
      subject(:scope) { described_class.with_due_notifications }

      context 'when all the users match a due date' do
        # time_travel_to doesn't work with before_all and didn't want to use before to
        # avoid bad performance
        let!(:pipl_users) do
          create(:pipl_user, initial_email_sent_at: Time.current - 30.days)
          create(:pipl_user, initial_email_sent_at: Time.current - 53.days)
          create(:pipl_user, initial_email_sent_at: Time.current - 59.days)
        end

        it 'returns all the user_details' do
          result = scope

          expect(result.count).to eq(3)
        end
      end

      context 'when some users match a due date' do
        let!(:pipl_users) do
          create(:pipl_user, initial_email_sent_at: Time.current)
          create(:pipl_user, initial_email_sent_at: Time.current - 30.days)
        end

        it 'returns only the matched results' do
          result = scope
          expect(result.count).to eq(1)
          expect(result.first.initial_email_sent_at).to eq(Time.current - 30.days)
        end
      end

      context 'when days does not match any records' do
        let!(:pipl_users) do
          create(:pipl_user, initial_email_sent_at: Time.current)
        end

        it 'does not return any results' do
          result = scope

          expect(result.count).to eq(0)
        end
      end
    end
  end

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

  describe '#pipl_access_end_date' do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: Time.zone.today) }

    subject(:pipl_access_end_date) { pipl_user.pipl_access_end_date }

    it 'returns the pipl deadline', :freeze_time do
      expect(pipl_access_end_date).to eq(Time.zone.today + described_class::NOTICE_PERIOD)
    end

    context 'when an email has not been sent' do
      before do
        pipl_user.update!(initial_email_sent_at: nil)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#reset_notification!' do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: Time.zone.today) }

    subject(:reset_notification!) { pipl_user.reset_notification! }

    it 'sets the timestamp to nil', :freeze_time do
      expect { reset_notification! }
        .to change { pipl_user.reload.initial_email_sent_at }
              .from(Time.zone.today)
              .to(nil)
    end
  end

  describe '#notification_sent!', :freeze_time do
    let(:pipl_user) { create(:pipl_user) }

    subject(:notification_sent!) { pipl_user.notification_sent! }

    it 'sets the timestamp to the current time' do
      expect { notification_sent! }
        .to change { pipl_user.reload.initial_email_sent_at }
              .from(nil)
              .to(Time.current)
    end
  end

  describe '#remaining_pipl_access_days' do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: 10.days.ago) }

    subject(:remaining_pipl_access_days) { pipl_user.remaining_pipl_access_days }

    it 'calculate the remaining pipl access days', :freeze_time do
      expect(remaining_pipl_access_days).to be(50)
    end
  end
end
