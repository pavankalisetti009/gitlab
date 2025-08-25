# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersionDependency, feature_category: :workflow_catalog do
  subject(:version) { build_stubbed(:ai_catalog_item_version_dependency) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:dependency).required.inverse_of(:reverse_dependencies) }
    it { is_expected.to belong_to(:ai_catalog_item_version).required }
  end
end
