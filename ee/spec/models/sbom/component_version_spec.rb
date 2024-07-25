# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersion, type: :model, feature_category: :dependency_management do
  describe 'associations' do
    it { is_expected.to belong_to(:component).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_length_of(:version).is_at_most(255) }
  end

  describe '.by_component_id_and_version' do
    let_it_be(:matching_version) { create(:sbom_component_version) }
    let_it_be(:non_matching_version) { create(:sbom_component_version) }

    subject(:results) do
      described_class.by_component_id_and_version(matching_version.component_id, matching_version.version)
    end

    it 'returns only the matching version' do
      expect(results.to_a).to eq([matching_version])
    end
  end
end
