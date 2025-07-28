# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::InventoryFilter, feature_category: :security_asset_inventories do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project_name) }
    it { is_expected.to validate_presence_of(:traversal_ids) }
    it { is_expected.to validate_inclusion_of(:archived).in_array([true, false]) }

    context 'for vulnerability counters attributes' do
      where(:attribute) do
        %i[
          total
          critical
          high
          medium
          low
          info
          unknown
        ]
      end

      with_them do
        it { is_expected.to validate_numericality_of(attribute).is_greater_than_or_equal_to(0) }
        it { is_expected.not_to allow_value(nil).for(attribute) }
      end
    end

    context 'for analyzer statuses enums' do
      where(:attribute) do
        Enums::Security.extended_analyzer_types.keys
      end

      with_them do
        it { is_expected.to validate_presence_of(attribute) }

        it 'validates enum' do
          is_expected.to define_enum_for(attribute)
            .with_values(Enums::Security.analyzer_statuses).with_prefix(attribute)
        end
      end
    end
  end

  context 'with loose foreign key on security_inventory_filters.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:security_inventory_filters, project: parent) }
    end
  end

  describe 'scopes' do
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }
    let_it_be(:inventory_filter1) { create(:security_inventory_filters, project: project1) }
    let_it_be(:inventory_filter2) { create(:security_inventory_filters, project: project2) }

    describe '.by_project_id' do
      subject { described_class.by_project_id(project1.id) }

      it 'returns filters for the specified project only' do
        is_expected.to contain_exactly(inventory_filter1)
      end
    end
  end
end
