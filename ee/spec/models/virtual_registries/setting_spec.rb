# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Setting, :aggregate_failures, feature_category: :virtual_registry do
  describe 'validations' do
    it { is_expected.to allow_value(true, false).for(:enabled) }
    it { is_expected.not_to allow_value(nil).for(:enabled) }
    it { is_expected.to validate_presence_of(:group) }

    context 'when validating root group' do
      let(:root_group) { create(:group) }
      let(:subgroup) { create(:group, parent: root_group) }

      it 'allows root groups' do
        setting = build(:virtual_registries_setting, group: root_group)

        expect(setting).to be_valid
      end

      it 'rejects subgroups' do
        setting = build(:virtual_registries_setting, group: subgroup)

        expect(setting).not_to be_valid
        expect(setting.errors[:group]).to include('must be a top level Group')
      end
    end
  end

  describe '.find_for_group' do
    let_it_be(:group) { create(:group) }

    subject { described_class.find_for_group(group) }

    context 'when a setting exists for the group' do
      let_it_be(:expected_setting) { create(:virtual_registries_setting, group: group) }
      let_it_be(:other_setting) { create(:virtual_registries_setting) }

      it { is_expected.to eq(expected_setting) }
    end

    context 'when a setting does not exist for the group' do
      it { is_expected.to be_a_new(described_class) }
      it { is_expected.to have_attributes(group: group, enabled: true) }
    end
  end
end
