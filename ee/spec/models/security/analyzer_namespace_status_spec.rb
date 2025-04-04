# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatus, feature_category: :security_asset_inventories do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:analyzer_type) }
    it { is_expected.to validate_presence_of(:traversal_ids) }

    it { is_expected.to validate_numericality_of(:success).is_greater_than_or_equal_to(0) }
    it { is_expected.not_to allow_value(nil).for(:success) }

    it { is_expected.to validate_numericality_of(:failure).is_greater_than_or_equal_to(0) }
    it { is_expected.not_to allow_value(nil).for(:failure) }
  end

  context 'with loose foreign key on analyzer_namespace_statuses.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:namespace) }
      let_it_be(:model) { create(:analyzer_namespace_status, namespace: parent) }
    end
  end
end
