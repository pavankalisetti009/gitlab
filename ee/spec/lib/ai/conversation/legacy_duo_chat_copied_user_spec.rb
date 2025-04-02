# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::Conversation::LegacyDuoChatCopiedUser, :clean_gitlab_redis_shared_state, feature_category: :duo_chat do
  let(:redis) { Gitlab::Redis::SharedState.with { |redis| redis } }
  let(:user_id) { 123 }

  describe '.add' do
    it 'adds a value to the Redis set' do
      described_class.add(user_id)
      ttl = redis.ttl(described_class::KEY)

      expect(redis.sismember(described_class::KEY, user_id)).to be true
      expect(ttl).to be_within(5).of(30.days.to_i)
    end
  end

  describe '.include?' do
    context 'when value exists in the set' do
      it 'returns true' do
        described_class.add(user_id)

        expect(described_class.include?(user_id)).to be true
      end
    end

    context 'when value does not exist in the set' do
      it 'returns false' do
        expect(described_class.include?(user_id)).to be false
      end
    end
  end
end
