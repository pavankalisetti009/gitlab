# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfileTrigger, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group) }

  describe 'associations' do
    it { is_expected.to belong_to(:scan_profile).class_name('Security::ScanProfile').required }
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    subject { create(:security_scan_profile_trigger, namespace: group, scan_profile: scan_profile) }

    it { is_expected.to validate_presence_of(:trigger_type) }
    it { is_expected.to validate_uniqueness_of(:security_scan_profile_id).scoped_to(:trigger_type) }
  end

  context 'with loose foreign key on namespaces.id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { group }
      let_it_be(:model) { create(:security_scan_profile_trigger, scan_profile: scan_profile, namespace: parent) }
    end
  end
end
