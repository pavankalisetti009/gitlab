# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Cache, :clean_gitlab_redis_cache, feature_category: :global_search do
  let(:search_mode) { 'regex' }
  let(:per_page) { 20 }
  let(:query) { 'foo' }
  let_it_be(:user1) { build(:user, id: 1) }
  let(:page) { 1 }
  let(:project_id) { 1 }
  let(:group_id) { 2 }
  let(:total_count) { 3 }
  let(:file_count) { 3 }
  let(:response) { [search_results, total_count, file_count] }
  let(:search_results) do
    { 0 => { project_id: 1 }, 1 => { project_id: 2 }, 2 => { project_id: 3 } }
  end

  let(:filters) do
    {}
  end

  let(:default_options) do
    { per_page: per_page, max_per_page: 40, search_mode: search_mode, filters: filters }
  end

  subject(:cache) do
    described_class.new(
      query,
      **default_options.merge(current_user: user1, project_id: project_id, group_id: group_id, page: page)
    )
  end

  before do
    stub_const("#{described_class.name}::MAX_PAGES", 2)
  end

  describe '#fetch' do
    context 'when application setting zoekt_cache_response is disabled', :zoekt_cache_disabled do
      it 'does not read or update cache' do
        expect(cache).not_to receive(:read_cache)
        expect(cache).not_to receive(:update_cache!)

        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(page)
          response
        end

        expect(data).to eq(response)
      end
    end

    context 'when read_cache returns nothing' do
      it 'updates cache' do
        expect(cache).to receive(:read_cache)
        expect(cache).to receive(:update_cache!)

        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(described_class::MAX_PAGES)
          response
        end

        expect(data).to eq(response)
      end
    end

    context 'when read_cache returns data' do
      it 'does not update cache' do
        expect(cache).to receive(:read_cache).and_return([search_results, total_count, file_count])
        expect(cache).not_to receive(:update_cache!)

        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(described_class::MAX_PAGES)
          response
        end

        expect(data).to eq(response)
      end
    end

    context 'when page is higher than the limit' do
      let(:page) { 3 }

      it 'sets the correct page limit' do
        data = cache.fetch do |page_limit|
          expect(page_limit).to eq(page)
          response
        end

        expect(data).to eq(response)
      end
    end

    describe 'cache key' do
      let(:redis) { ::Gitlab::Redis::Cache.with { |r| r } }
      let(:data) { "#{query}-g#{group_id}-p#{project_id}-#{search_mode}-f-#{Gitlab::Json.generate(filters.sort)}" }
      let(:fingerprint) { OpenSSL::Digest.hexdigest('SHA256', data) }

      context 'when current_user is nil' do
        let(:user1) { nil }

        it 'sets 0 for user_id key' do
          cache.fetch { response }
          expect(redis.exists?("cache:zoekt:{0}/#{fingerprint}/#{per_page}/#{page}")).to be true
        end
      end

      context 'when current_user exists' do
        it 'sets user_id in the key' do
          cache.fetch { response }
          expect(redis.exists?("cache:zoekt:{#{user1.id}}/#{fingerprint}/#{per_page}/#{page}")).to be true
        end
      end
    end
  end
end
