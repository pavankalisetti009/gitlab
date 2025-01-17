# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Aggregations::BaseLazyAggregate, feature_category: :code_quality do
  let(:query_ctx) { {} }
  let(:pending_item) { 42 }
  let(:test_block) { -> { 'block result' } }

  let(:aggregate_class) do
    Class.new(described_class) do
      def initialize(query_ctx, pending_item, &block)
        @block = block
        super(query_ctx, pending_item)
      end

      def state_key
        :test_aggregate_key
      end

      def initial_state
        { pending_ids: Set.new, facets: Set.new }
      end

      def queued_objects
        lazy_state[:pending_ids]
      end

      def result
        lazy_state[:facets]
      end

      def load_queued_records
        lazy_state[:facets] << :loaded
      end

      def block_params
        [:param1, :param2]
      end
    end
  end

  let(:aggregate) { aggregate_class.new(query_ctx, pending_item) }

  describe '#initialize' do
    it 'initializes lazy state in query context if not present' do
      aggregate
      expect(query_ctx[:test_aggregate_key]).to eq(pending_ids: Set.new([42]), facets: Set.new)
    end

    it 'uses existing lazy state if already initialized in query context' do
      query_ctx[:test_aggregate_key] = {
        pending_ids: Set.new([42]),
        facets: Set.new([:some_facet])
      }

      aggregate
      expect(query_ctx[:test_aggregate_key]).to eq(
        pending_ids: Set.new([42]),
        facets: Set.new([:some_facet])
      )
    end

    it 'assigns the lazy state to @lazy_state' do
      lazy_state = aggregate.instance_variable_get(:@lazy_state)
      expect(lazy_state).to eq(query_ctx[:test_aggregate_key])
    end
  end

  describe '#execute' do
    context 'when given a block' do
      let(:aggregate) { aggregate_class.new(query_ctx, pending_item) { test_block.call } }

      it 'loads pending items and executes block' do
        result = aggregate.execute

        expect(query_ctx[:test_aggregate_key][:facets]).to include(:loaded)
        expect(result).to eq('block result')
      end
    end

    it 'returns result if no block is provided' do
      result = aggregate.execute
      expect(result).to eq(Set.new([:loaded]))
    end

    context 'when implementation does not implement required methods' do
      let(:aggregate_class) { Class.new(described_class) }

      where(:method) do
        %i[queued_objects initial_state result load_queued_records block_params]
      end

      with_them do
        it 'raises NotImplementedError' do
          expect { aggregate.send(method) }.to raise_error(NoMethodError)
        end
      end
    end
  end
end
