# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::ComponentResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:component_1) { create(:sbom_component, name: "activestorage") }
  let_it_be(:component_2) { create(:sbom_component, name: "activesupport") }
  let_it_be(:component_3) { create(:sbom_component, name: "log4j") }

  describe '#resolve' do
    subject { resolve_components(args: { name: name }) }

    context 'when not given a query string' do
      let(:name) { nil }

      it { is_expected.to match_array([component_1, component_2, component_3]) }
    end

    context 'when given a query string' do
      let(:name) { "actives" }

      it { is_expected.to match_array([component_1, component_2]) }
    end
  end

  def resolve_components(args: {})
    resolve(
      described_class,
      obj: nil,
      args: args,
      ctx: {}
    )
  end
end
