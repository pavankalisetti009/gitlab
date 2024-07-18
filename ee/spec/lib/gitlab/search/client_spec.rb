# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::Search::Client, feature_category: :global_search do
  let(:adapter) { ::Gitlab::Elastic::Helper.default.client }

  subject(:client) { described_class.new(adapter: adapter) }

  it 'delegates to adapter', :aggregate_failures do
    described_class::DELEGATED_METHODS.each do |msg|
      expect(client).to respond_to(msg)
      expect(adapter).to receive(msg)
      client.send(msg)
    end
  end

  describe '.execute_search' do
    let(:options) { { klass: Project } }
    let(:query) { { foo: 'bar' } }

    it 'calls search with the expected query' do
      expect(adapter).to receive(:search)
        .with(a_hash_including(timeout: '30s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

      client.execute_search(query: query, options: options) do |response|
        expect(response).to eq(true)
      end
    end

    context 'when count_only is set to true in options' do
      let(:options) { { klass: Project, count_only: true } }

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '1s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

        client.execute_search(query: query, options: options) do |response|
          expect(response).to eq(true)
        end
      end
    end

    context 'when index_name is set to in options' do
      let(:options) { { index_name: 'foo-bar', count_only: true } }

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '1s', index: 'foo-bar', body: { foo: 'bar' })).and_return(true)

        client.execute_search(query: query, options: options) do |response|
          expect(response).to eq(true)
        end
      end
    end
  end
end
