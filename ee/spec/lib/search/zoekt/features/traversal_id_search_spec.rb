# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Features::TraversalIdSearch, feature_category: :global_search do
  it_behaves_like 'zoekt feature', feature: :traversal_id_search, feature_flag: :zoekt_traversal_id_queries

  describe '#preflight_checks_passed?' do
    let_it_be(:namespace) { create(:group) }
    let(:feature) { described_class.new(nil, group_id: namespace.id) }

    subject(:result) { feature.preflight_checks_passed? }

    it { is_expected.to be true }
  end
end
