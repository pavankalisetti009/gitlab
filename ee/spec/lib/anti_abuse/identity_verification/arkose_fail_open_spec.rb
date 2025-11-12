# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::IdentityVerification::ArkoseFailOpen,
  :clean_gitlab_redis_shared_state,
  feature_category: :instance_resiliency do
  subject(:fail_open) { described_class }

  let(:bucket_hours)   { described_class::BUCKET_DURATION_HOURS }
  let(:success_prefix) { described_class::COUNTER_SUCCESS_KEY_PREFIX }
  let(:failure_prefix) { described_class::COUNTER_FAILURE_KEY_PREFIX }

  # Freeze at bucket boundary for determinism
  let(:t0) { Time.zone.parse('2025-11-05 00:00:00') }

  # ---------- Helpers ----------
  def bucket_id(at_time)
    "#{at_time.to_date.strftime('%Y%m%d')}-#{at_time.hour / bucket_hours}"
  end

  def key_for(prefix, at_time)
    "#{prefix}#{bucket_id(at_time)}"
  end

  def redis_get(key)
    Gitlab::Redis::SharedState.with { |r| r.get(key)&.to_i }
  end

  def redis_ttl(key)
    Gitlab::Redis::SharedState.with { |r| r.ttl(key) }
  end
  # -----------------------------

  describe '#track_token_verification_result' do
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(track_arkose_token_verification_results: false)
      end

      it 'does not increment SUCCESS counters' do
        key = key_for(success_prefix, t0)

        expect do
          fail_open.track_token_verification_result(success: true)
        end.not_to change { redis_get(key) }
      end

      it 'does not increment FAILURE counters' do
        key = key_for(failure_prefix, t0)

        expect do
          fail_open.track_token_verification_result(success: false)
        end.not_to change { redis_get(key) }
      end
    end

    context 'when feature flag is enabled' do
      it 'increments SUCCESS counter within the same bucket' do
        travel_to(t0) do
          key = key_for(success_prefix, t0)

          expect do
            fail_open.track_token_verification_result(success: true)
          end.to change { redis_get(key) }.from(nil).to(1)
        end

        t1 = t0 + 30.minutes
        travel_to(t1) do
          key = key_for(success_prefix, t1)

          expect do
            fail_open.track_token_verification_result(success: true)
          end.to change { redis_get(key) }.from(1).to(2)
        end
      end

      it 'increments FAILURE counter within the same bucket' do
        travel_to(t0) do
          key = key_for(failure_prefix, t0)

          expect do
            fail_open.track_token_verification_result(success: false)
          end.to change { redis_get(key) }.from(nil).to(1)
        end

        t1 = t0 + 30.minutes
        travel_to(t1) do
          key = key_for(failure_prefix, t1)

          expect do
            fail_open.track_token_verification_result(success: false)
          end.to change { redis_get(key) }.from(1).to(2)
        end
      end

      it 'does not reset TTL when incrementing within the same bucket' do
        travel_to(t0) do
          key = key_for(success_prefix, t0)

          fail_open.track_token_verification_result(success: true)
          ttl_initial = redis_ttl(key)

          travel 1.minute

          fail_open.track_token_verification_result(success: true)
          ttl_after = redis_ttl(key)

          expect(redis_get(key)).to eq(2)
          expect(ttl_after).to be <= ttl_initial
        end
      end

      it 'starts SUCCESS from zero in a new bucket and sets TTL once' do
        travel_to(t0) do
          key0 = key_for(success_prefix, t0)

          expect do
            fail_open.track_token_verification_result(success: true)
          end.to change { redis_get(key0) }.from(nil).to(1)
        end

        t1 = t0 + bucket_hours.hours + 5.minutes
        travel_to(t1) do
          key1 = key_for(success_prefix, t1)

          expect do
            fail_open.track_token_verification_result(success: true)
          end.to change { redis_get(key1) }.from(nil).to(1)

          expect(redis_ttl(key1)).to be > 0

          key0 = key_for(success_prefix, t0)
          expect(redis_get(key0)).to eq(1)
        end
      end

      it 'starts FAILURE from zero in a new bucket and sets TTL once' do
        travel_to(t0) do
          key0 = key_for(failure_prefix, t0)

          expect do
            fail_open.track_token_verification_result(success: false)
          end.to change { redis_get(key0) }.from(nil).to(1)
        end

        t1 = t0 + bucket_hours.hours + 5.minutes
        travel_to(t1) do
          key1 = key_for(failure_prefix, t1)

          expect do
            fail_open.track_token_verification_result(success: false)
          end.to change { redis_get(key1) }.from(nil).to(1)

          expect(redis_ttl(key1)).to be > 0

          key0 = key_for(failure_prefix, t0)
          expect(redis_get(key0)).to eq(1)
        end
      end

      it 'rescues and reports unexpected errors' do
        allow(fail_open).to receive(:increment_counter!).and_raise(Redis::BaseError.new('boom'))

        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(Redis::BaseError))

        expect { fail_open.track_token_verification_result(success: true) }.not_to raise_error
      end
    end
  end
end
