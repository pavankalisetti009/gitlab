# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::RedisBatchUsage, :clean_gitlab_redis_shared_state, feature_category: :continuous_integration do
  let_it_be(:namespace) { create(:namespace) }
  let(:redis_batch_usage) { described_class.new(namespace_id: namespace.id) }

  def namespace_key_exists?
    Gitlab::Redis::SharedState.with do |redis|
      redis.exists(redis_batch_usage.redis_key) > 0
    end
  rescue StandardError
    false
  end

  describe '#batch_increment' do
    it 'increments amount_used when provided' do
      redis_batch_usage.batch_increment(amount_used: 10.5)

      expect(redis_batch_usage.fetch_field('amount_used')).to eq(10.5)
      expect(redis_batch_usage.fetch_field('shared_runners_duration')).to eq(0.0)
    end

    it 'increments shared_runners_duration when provided' do
      redis_batch_usage.batch_increment(shared_runners_duration: 25.0)

      expect(redis_batch_usage.fetch_field('amount_used')).to eq(0.0)
      expect(redis_batch_usage.fetch_field('shared_runners_duration')).to eq(25.0)
    end

    it 'increments both fields when provided' do
      redis_batch_usage.batch_increment(amount_used: 15.5, shared_runners_duration: 30.0)

      expect(redis_batch_usage.fetch_field('amount_used')).to eq(15.5)
      expect(redis_batch_usage.fetch_field('shared_runners_duration')).to eq(30.0)
    end

    it 'accumulates multiple increments' do
      redis_batch_usage.batch_increment(amount_used: 10.0, shared_runners_duration: 20.0)
      redis_batch_usage.batch_increment(amount_used: 5.5, shared_runners_duration: 15.0)

      expect(redis_batch_usage.fetch_field('amount_used')).to eq(15.5)
      expect(redis_batch_usage.fetch_field('shared_runners_duration')).to eq(35.0)
    end

    it 'does nothing when both values are zero' do
      redis_batch_usage.batch_increment(amount_used: 0, shared_runners_duration: 0)

      expect(namespace_key_exists?).to be_falsey
    end

    it 'does nothing when both values are negative' do
      redis_batch_usage.batch_increment(amount_used: -5, shared_runners_duration: -10)

      expect(namespace_key_exists?).to be_falsey
    end

    it 'only increments positive values' do
      redis_batch_usage.batch_increment(amount_used: 10.0, shared_runners_duration: -5)

      expect(redis_batch_usage.fetch_field('amount_used')).to eq(10.0)
      expect(redis_batch_usage.fetch_field('shared_runners_duration')).to eq(0.0)
    end

    it 'sets TTL on the Redis key' do
      redis_batch_usage.batch_increment(amount_used: 10.0)

      Gitlab::Redis::SharedState.with do |redis|
        ttl = redis.ttl(redis_batch_usage.redis_key)
        expect(ttl).to be > 0
        expect(ttl).to be <= described_class::TTL_SECONDS
      end
    end

    it 'does nothing when called with no arguments' do
      redis_batch_usage.batch_increment

      expect(namespace_key_exists?).to be_falsey
    end
  end

  describe '#fetch_field' do
    before do
      redis_batch_usage.batch_increment(amount_used: 25.5, shared_runners_duration: 40.0)
    end

    it 'returns the correct value for amount_used' do
      expect(redis_batch_usage.fetch_field('amount_used')).to eq(25.5)
      expect(redis_batch_usage.fetch_field(:amount_used)).to eq(25.5)
    end

    it 'returns the correct value for shared_runners_duration' do
      expect(redis_batch_usage.fetch_field('shared_runners_duration')).to eq(40.0)
      expect(redis_batch_usage.fetch_field(:shared_runners_duration)).to eq(40.0)
    end

    it 'returns 0.0 for invalid field names' do
      expect(redis_batch_usage.fetch_field('invalid_field')).to eq(0.0)
    end

    it 'returns 0.0 when key does not exist' do
      new_usage = described_class.new(namespace_id: 99999)
      expect(new_usage.fetch_field('amount_used')).to eq(0.0)
    end

    it 'tracks errors and returns 0.0 on Redis errors' do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(Redis::ConnectionError)
      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

      expect(redis_batch_usage.fetch_field('amount_used')).to eq(0.0)
    end
  end

  describe '#fetch_all_fields' do
    before do
      redis_batch_usage.batch_increment(amount_used: 25.5, shared_runners_duration: 40.0)
    end

    it 'returns all fields as a hash with float values' do
      result = redis_batch_usage.fetch_all_fields

      expect(result).to eq({
        'amount_used' => 25.5,
        'shared_runners_duration' => 40.0
      })
    end

    it 'returns empty hash when key does not exist' do
      new_usage = described_class.new(namespace_id: 99999)
      expect(new_usage.fetch_all_fields).to eq({})
    end

    it 'tracks errors and returns empty hash on Redis errors' do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(Redis::ConnectionError)
      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

      expect(redis_batch_usage.fetch_all_fields).to eq({})
    end
  end

  describe '#delete_key' do
    before do
      redis_batch_usage.batch_increment(amount_used: 10.0)
    end

    it 'deletes the Redis key' do
      expect(namespace_key_exists?).to be_truthy

      redis_batch_usage.delete_key

      expect(namespace_key_exists?).to be_falsey
    end
  end

  describe '#key_exists?' do
    it 'returns false when key does not exist' do
      expect(namespace_key_exists?).to be_falsey
    end

    it 'returns true when key exists' do
      redis_batch_usage.batch_increment(amount_used: 10.0)

      expect(namespace_key_exists?).to be_truthy
    end

    it 'returns false on Redis errors' do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(Redis::ConnectionError)

      expect(namespace_key_exists?).to be_falsey
    end
  end

  describe '#redis_key' do
    it 'returns the correct Redis key format' do
      expected_key = "minutes_batch:namespace_monthly_usages:{#{namespace.id}}"
      expect(redis_batch_usage.redis_key).to eq(expected_key)
    end
  end

  describe '#lock_key' do
    it 'returns the correct lock key format' do
      expected_key = "minutes_batch:namespace_monthly_usages:{#{namespace.id}}:lock"
      expect(redis_batch_usage.lock_key).to eq(expected_key)
    end
  end
end
