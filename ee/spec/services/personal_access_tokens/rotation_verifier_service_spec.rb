# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RotationVerifierService, feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be(:no_pat_user) { create(:user) }
  let_it_be(:active_pat) { create(:personal_access_token, user: user, expires_at: 2.months.from_now, created_at: 1.month.ago) }

  describe '#clear_cache', :use_clean_rails_memory_store_caching do
    let_it_be(:cache_keys) { %w[token_expired_rotation token_expiring_rotation] }

    before do
      cache_keys.each do |key|
        Rails.cache.write(['users', user.id, key], double)
      end
    end

    it 'clears cache' do
      described_class.new(user).clear_cache

      cache_keys.each do |key|
        expect(Rails.cache.read(['users', user.id, key])).to be_nil
      end
    end
  end
end
