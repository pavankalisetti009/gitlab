# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::API::Entities::Epic, feature_category: :portfolio_management do
  subject(:entity) { described_class.new(epic).as_json }

  let_it_be(:epic) { create(:epic) }

  it 'exposes the work item id' do
    expect(entity[:id]).to eq(epic.id)
    expect(entity[:work_item_id]).to eq(epic.work_item.id)
  end
end
