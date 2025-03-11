# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::InventoryController, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }

  before do
    stub_licensed_features(security_inventory: true)
    stub_feature_flags(security_inventory_dashboard: true)

    sign_in(user)
  end

  describe '#show', :aggregate_failures do
    it_behaves_like 'internal event tracking' do
      let(:event) { 'view_group_security_inventory' }
      let(:namespace) { group }

      subject(:request) { get group_security_inventory_path(group) }
    end
  end
end
