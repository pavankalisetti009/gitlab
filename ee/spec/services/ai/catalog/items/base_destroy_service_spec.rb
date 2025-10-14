# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Items::BaseDestroyService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  before do
    enable_ai_catalog
  end

  it_behaves_like described_class do
    let!(:item) { create(:ai_catalog_item, public: true, project: project) }
    let(:not_found_error) { 'Item not found' }
  end
end
