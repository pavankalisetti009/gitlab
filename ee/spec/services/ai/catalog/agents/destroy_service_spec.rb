# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::DestroyService, feature_category: :workflow_catalog do
  it_behaves_like Ai::Catalog::Items::BaseDestroyService do
    let_it_be_with_reload(:incorrect_item_type) { create(:ai_catalog_flow, project: project) }
    let!(:item) { create(:ai_catalog_agent, project: project) }
    let(:not_found_error) { 'Agent not found' }
  end
end
