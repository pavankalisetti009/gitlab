# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::ConfiguredItemsResolver, feature_category: :workflow_catalog do
  subject(:resolver) { described_class }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :group_id,
      :include_inherited,
      :item_id,
      :project_id
    )
  end
end
