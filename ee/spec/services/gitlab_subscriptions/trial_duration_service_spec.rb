# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialDurationService, feature_category: :acquisition do
  describe '#execute', :saas, :sidekiq_inline, :use_clean_rails_memory_store_caching do
    let_it_be(:free_duration) { 1 }
    let_it_be(:premium_duration) { 2 }
    let_it_be(:premium_next_duration) { 3 }
    let_it_be(:duo_enterprise_duration) { 4 }
    let_it_be(:duo_enterprise_next_duration) { 5 }
    let_it_be(:corrupted_trial_type) { '_corrupted_trial_type_' }
    let_it_be(:corrupted_duration) { 6 }
    let_it_be(:corrupted_next_duration) { 7 }
    let_it_be(:default_free_duration) { 30 }
    let_it_be(:default_duo_enterprise_duration) { 60 }

    let_it_be(:trial_types) do
      {
        GitlabSubscriptions::Trials::FREE_TRIAL_TYPE => { duration_days: free_duration },
        GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE => {
          duration_days: premium_duration,
          next_duration_days: premium_next_duration,
          next_active_time: 1.day.ago.to_s
        },
        GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE => {
          duration_days: duo_enterprise_duration,
          next_duration_days: duo_enterprise_next_duration,
          next_active_time: 1.day.from_now.to_s
        },
        corrupted_trial_type => {
          duration_days: corrupted_duration,
          next_duration_days: corrupted_next_duration,
          next_active_time: {}
        }
      }
    end

    let(:response) { { success: true, data: { trial_types: trial_types } } }

    subject(:service) { described_class.new }

    before do
      allow(Gitlab::SubscriptionPortal::Client).to receive(:namespace_trial_types).and_return(response)
    end

    it 'returns default duration, makes a request, caches it, and returns correct duration on the next execution' do
      expect(service.execute).to eq(default_free_duration) # first execution to spawn the worker
      expect(service.execute).to eq(free_duration)
    end

    context 'when trial type is specified' do
      before do
        service.execute # first execution to spawn the worker
      end

      subject(:service) { described_class.new(trial_type) }

      context 'with next_active_time' do
        context 'when next active time is in the past' do
          let(:trial_type) { GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE }

          it { expect(service.execute).to eq(premium_next_duration) }
        end

        context 'when next active time is in the future' do
          let(:trial_type) { GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE }

          it { expect(service.execute).to eq(duo_enterprise_duration) }
        end

        context 'when next active time is corrupted' do
          let(:trial_type) { corrupted_trial_type }

          it { expect(service.execute).to eq(corrupted_duration) }
        end
      end

      context 'when trial type is missing from response' do
        let(:trial_type) { '__trial_type__' }

        it { expect(service.execute).to eq(default_free_duration) }
      end
    end

    context 'with an unsuccessful CustomersDot query' do
      let(:response) { { success: false } }

      it { expect(service.execute).to eq(default_free_duration) }

      context 'when trial type is specified' do
        let(:trial_type) { GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE }

        subject(:service) { described_class.new(trial_type) }

        it { expect(service.execute).to eq(default_duo_enterprise_duration) }

        context 'when trial type is missing from defaults' do
          let(:trial_type) { '__trial_type__' }

          it { expect(service.execute).to eq(default_free_duration) }
        end
      end
    end
  end
end
