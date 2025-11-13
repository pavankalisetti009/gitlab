# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfileProject, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group) }

  describe 'associations' do
    it { is_expected.to belong_to(:scan_profile).class_name('Security::ScanProfile').required }
    it { is_expected.to belong_to(:project).required }
  end

  describe 'validations' do
    subject { create(:security_scan_profile_project, scan_profile: scan_profile, project: project) }

    it { is_expected.to validate_uniqueness_of(:project_id).scoped_to(:security_scan_profile_id) }
  end

  context 'with loose foreign key on security_scan_profiles_projects.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:security_scan_profile_project, scan_profile: scan_profile, project: parent) }
    end
  end
end
