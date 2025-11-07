# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MavenRegistryDetails'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[id name description updated_at upstreams] }

  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_graphql_fields(fields) }
end
