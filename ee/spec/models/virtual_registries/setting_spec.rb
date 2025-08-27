# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Setting, feature_category: :virtual_registry do
  describe 'validations' do
    it { is_expected.to allow_value(true, false).for(:enabled) }
    it { is_expected.not_to allow_value(nil).for(:enabled) }
    it { is_expected.to validate_presence_of(:group) }

    context 'when validating root group', :aggregate_failures do
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

  describe '.for_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:expected_setting) { create(:virtual_registries_setting, group: group) }
    let_it_be(:other_setting) { create(:virtual_registries_packages_maven_registry) }

    subject { described_class.for_group(group) }

    it { is_expected.to eq([expected_setting]) }
  end
end
