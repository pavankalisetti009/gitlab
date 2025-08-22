# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Update, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiCatalogItemConsumerUpdate') }

  it { expect(described_class).to require_graphql_authorizations(:admin_ai_catalog_item_consumer) }

  it { is_expected.to have_graphql_fields(:item_consumer, :errors, :client_mutation_id) }

  it { is_expected.to have_graphql_arguments(:id, :enabled, :locked, :pinned_version_prefix, :client_mutation_id) }
end
