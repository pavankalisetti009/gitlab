# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyInterface, feature_category: :dependency_management do
  let(:fields) { %i[id name version packager location licenses reachability vulnerability_count] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
