# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfile, feature_category: :security_asset_inventories do
  let_it_be(:root_level_group) { create(:group) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:scan_type) }
    it { is_expected.to validate_inclusion_of(:gitlab_recommended).in_array([true, false]) }
    it { is_expected.to validate_length_of(:description).is_at_most(2047) }

    context 'when validating uniqueness of name scoped to namespace and type' do
      subject { create(:security_scan_profile, namespace: root_level_group, scan_type: :sast) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to([:namespace_id, :scan_type]) }
    end

    describe '#root_namespace_validation' do
      let_it_be(:subgroup) { create(:group, parent: root_level_group) }

      it 'is valid for root group namespace' do
        expect(build(:security_scan_profile, namespace: root_level_group)).to be_valid
      end

      it 'is invalid for non-root namespaces' do
        profile = build(:security_category, namespace: subgroup)

        expect(profile).not_to be_valid
        expect(profile.errors[:namespace]).to include('must be a root group.')
      end
    end
  end

  describe 'attribute stripping' do
    it 'strips whitespace from name' do
      scan_profile = build(:security_scan_profile, name: '  Test Profile  ')
      scan_profile.valid?
      expect(scan_profile.name).to eq('Test Profile')
    end

    it 'strips whitespace from description' do
      scan_profile = build(:security_scan_profile, description: '  Test Description  ')
      scan_profile.valid?
      expect(scan_profile.description).to eq('Test Description')
    end
  end

  context 'with loose foreign key on security_scan_profiles.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { root_level_group }
      let_it_be(:model) { create(:security_scan_profile, namespace: parent) }
    end
  end
end
