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

  describe 'scopes' do
    describe '.not_in_root_namespace' do
      let_it_be(:root_namespace) { create(:group) }
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:project_in_root) { create(:project, namespace: root_namespace) }
      let_it_be(:project_in_other) { create(:project, namespace: other_namespace) }

      let_it_be(:scan_profile_in_root) { create(:security_scan_profile, namespace: root_namespace) }
      let_it_be(:scan_profile_in_other) { create(:security_scan_profile, namespace: other_namespace) }

      let_it_be(:association_in_root) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_root, project: project_in_root)
      end

      let_it_be(:association_in_other) do
        create(:security_scan_profile_project, scan_profile: scan_profile_in_other, project: project_in_other)
      end

      it 'returns associations where scan profile is not in the given root namespace' do
        result = described_class.not_in_root_namespace(root_namespace)

        expect(result).to contain_exactly(association_in_other)
      end

      it 'returns empty when all associations are in the root namespace' do
        result = described_class.not_in_root_namespace(other_namespace)

        expect(result).to contain_exactly(association_in_root)
      end
    end
  end

  context 'with loose foreign key on security_scan_profiles_projects.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { project }
      let_it_be(:model) { create(:security_scan_profile_project, scan_profile: scan_profile, project: parent) }
    end
  end
end
