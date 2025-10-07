# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.aiCatalogItem', feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:item) { create(:ai_catalog_item, project: project) }

  let(:query) do
    <<~QUERY
    {
      project(fullPath: "#{project.full_path}") {
        aiCatalogItem(id: "#{global_id_of(item)}") {
          id
        }
      }
    }
    QUERY
  end

  let(:item_data) { graphql_data.dig('project', 'aiCatalogItem', 'id') }

  before do
    enable_ai_catalog
  end

  context 'when the user can read items on the project' do
    before_all do
      project.add_developer(user)
    end

    it 'returns the item that matches the given ID' do
      post_graphql(query, current_user: user)

      expect(item_data).to eq(global_id_of(item).to_s)
    end

    context 'when the global_ai_catalog flag is disabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it 'returns null' do
        post_graphql(query, current_user: user)

        expect(item_data).to be_nil
      end
    end

    context 'when item ID belongs to another project' do
      let_it_be(:item) { create(:ai_catalog_item, project: create(:project)) }

      it 'returns null' do
        post_graphql(query, current_user: user)

        expect(item_data).to be_nil
      end
    end
  end

  context 'when the user cannot read items on the project' do
    it 'returns null' do
      post_graphql(query, current_user: user)

      expect(item_data).to be_nil
    end
  end
end
