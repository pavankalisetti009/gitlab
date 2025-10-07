# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Features::TraversalIdSearch, feature_category: :global_search do
  it_behaves_like 'zoekt feature', feature: :traversal_id_search, feature_flag: :zoekt_traversal_id_queries

  describe '#preflight_checks_passed?' do
    let_it_be(:namespace) { create(:group) }
    let(:root_namespace) { namespace.root_ancestor }
    let(:threshold) { ::Search::Zoekt::Settings.minimum_projects_for_traversal_id_search }
    let(:feature) { described_class.new(nil, group_id: namespace.id) }
    let(:project_count) { 3 }

    subject(:result) { feature.preflight_checks_passed? }

    before do
      stubbed_collection = double(:namespaces) # rubocop:disable RSpec/VerifiedDoubles -- verifying double must use private constant
      allow(Namespace).to receive(:by_root_id).with(root_namespace.id).and_return(stubbed_collection)
      allow(stubbed_collection).to receive_message_chain(:project_namespaces,
        :limit).with(threshold).and_return(stubbed_collection)
      allow(stubbed_collection).to receive(:count).and_return(project_count)
    end

    context 'when zoekt_traversal_id_queries feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_traversal_id_queries: false)
      end

      it { is_expected.to be false }
    end

    context 'when the project count is above the minimum threshold' do
      let(:project_count) { threshold + 1 }

      it { is_expected.to be true }
    end

    context 'when the project count is below the minimum threshold' do
      let(:project_count) { threshold - 1 }

      it { is_expected.to be false }
    end
  end
end
