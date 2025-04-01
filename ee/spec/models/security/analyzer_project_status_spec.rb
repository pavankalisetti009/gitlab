# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerProjectStatus, feature_category: :security_asset_inventories do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:analyzer_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:traversal_ids) }
  end

  context 'with loose foreign key on analyzer_project_statuses.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:analyzer_project_status, project: parent) }
    end
  end
end
