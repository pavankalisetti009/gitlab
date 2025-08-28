# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountAiCatalogItemsMetric, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  let_it_be(:agent_items) do
    [
      create(:ai_catalog_agent, public: true, organization: organization),
      create(:ai_catalog_agent, public: false, organization: organization),
      create(:ai_catalog_agent, created_at: 2.months.ago, public: false, organization: organization)
    ]
  end

  let_it_be(:flow_items) do
    [
      create(:ai_catalog_flow, public: true, organization: organization),
      create(:ai_catalog_flow, public: false, organization: organization),
      create(:ai_catalog_flow, created_at: 2.months.ago, public: true, organization: organization)
    ]
  end

  let_it_be(:agent_type) { Ai::Catalog::Item.item_types["agent"] }
  let_it_be(:flow_type) { Ai::Catalog::Item.item_types["flow"] }

  context 'with no options' do
    context 'with all time frame' do
      let(:expected_value) { 6 }
      let(:expected_query) do
        "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\""
      end

      it_behaves_like 'a correct instrumented metric value and query', time_frame: 'all', options: {}
    end
  end

  context 'with invalid item_type' do
    it 'raises ArgumentError' do
      expect { described_class.new(time_frame: 'all', options: { item_type: 'invalid_type' }) }
        .to raise_error(ArgumentError, /item_type 'invalid_type' must be one of/)
    end
  end

  context 'with item_type agent' do
    context 'with all time frame' do
      let(:expected_value) { 3 }
      let(:expected_query) do
        "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\" " \
          "WHERE \"ai_catalog_items\".\"item_type\" = #{agent_type}"
      end

      it_behaves_like 'a correct instrumented metric value and query',
        time_frame: 'all',
        options: { item_type: 'agent' }

      context 'with public visibility' do
        let(:expected_value) { 1 }
        let(:expected_query) do
          "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\" " \
            "WHERE \"ai_catalog_items\".\"item_type\" = #{agent_type} AND \"ai_catalog_items\".\"public\" = TRUE"
        end

        it_behaves_like 'a correct instrumented metric value and query',
          time_frame: 'all',
          options: { public: true, item_type: 'agent' }
      end

      context 'with private visibility' do
        let(:expected_value) { 2 }
        let(:expected_query) do
          "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\" " \
            "WHERE \"ai_catalog_items\".\"item_type\" = #{agent_type} AND \"ai_catalog_items\".\"public\" = FALSE"
        end

        it_behaves_like 'a correct instrumented metric value and query',
          time_frame: 'all',
          options: { public: false, item_type: 'agent' }
      end
    end
  end

  context 'with item_type flow' do
    context 'with all time frame' do
      let(:expected_value) { 3 }
      let(:expected_query) do
        "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\" " \
          "WHERE \"ai_catalog_items\".\"item_type\" = #{flow_type}"
      end

      it_behaves_like 'a correct instrumented metric value and query',
        time_frame: 'all',
        options: { item_type: 'flow' }

      context 'with public visibility' do
        let(:expected_value) { 2 }
        let(:expected_query) do
          "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\" " \
            "WHERE \"ai_catalog_items\".\"item_type\" = #{flow_type} AND \"ai_catalog_items\".\"public\" = TRUE"
        end

        it_behaves_like 'a correct instrumented metric value and query',
          time_frame: 'all',
          options: { public: true, item_type: 'flow' }
      end

      context 'with private visibility' do
        let(:expected_value) { 1 }
        let(:expected_query) do
          "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\" " \
            "WHERE \"ai_catalog_items\".\"item_type\" = #{flow_type} AND \"ai_catalog_items\".\"public\" = FALSE"
        end

        it_behaves_like 'a correct instrumented metric value and query',
          time_frame: 'all',
          options: { public: false, item_type: 'flow' }
      end
    end
  end

  context 'when no records exist' do
    before_all do
      Ai::Catalog::Item.delete_all
    end

    let(:expected_value) { 0 }

    let(:expected_query) do
      "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\""
    end

    it_behaves_like 'a correct instrumented metric value and query', time_frame: 'all', options: {}

    context 'with any item_type' do
      let(:expected_value) { 0 }

      let(:expected_query) do
        "SELECT COUNT(\"ai_catalog_items\".\"id\") FROM \"ai_catalog_items\" " \
          "WHERE \"ai_catalog_items\".\"item_type\" = #{agent_type}"
      end

      it_behaves_like 'a correct instrumented metric value and query', time_frame: 'all',
        options: { item_type: 'agent' }
    end
  end
end
