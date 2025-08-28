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
    let_it_be(:project1) { create(:project, name: 'security-project') }
    let_it_be(:project2) { create(:project, name: 'another-project') }
    let_it_be(:project3) { create(:project, name: 'test-project') }

    let_it_be(:inventory_filter_1) do
      create(:security_inventory_filters,
        project: project1,
        project_name: project1.name,
        critical: 5,
        high: 10,
        medium: 15,
        low: 20,
        sast: :failed,
        secret_detection: :success
      )
    end

    let_it_be(:inventory_filter_2) do
      create(:security_inventory_filters,
        project: project2,
        project_name: project2.name,
        critical: 0,
        high: 2,
        medium: 5,
        low: 10,
        sast: :success,
        secret_detection: :not_configured
      )
    end

    let_it_be(:inventory_filter_3) do
      create(:security_inventory_filters,
        project: project3,
        project_name: project3.name,
        critical: 3,
        high: 7,
        medium: 5,
        low: 1,
        sast: :not_configured,
        secret_detection: :success
      )
    end

    describe '.by_project_id' do
      subject { described_class.by_project_id(project1.id) }

      it 'returns filters for the specified project only' do
        is_expected.to contain_exactly(inventory_filter_1)
      end
    end

    describe '.by_severity_count' do
      subject { described_class.by_severity_count(severity, operator, count) }

      context 'with valid severity and operator' do
        let(:severity) { 'critical' }
        let(:count) { 3 }

        context 'with greater_than_or_equal_to operator' do
          let(:operator) { 'greater_than_or_equal_to' }

          it 'returns filters with critical count >= 3' do
            is_expected.to contain_exactly(inventory_filter_1, inventory_filter_3)
          end
        end

        context 'with less_than_or_equal_to operator' do
          let(:operator) { 'less_than_or_equal_to' }

          it 'returns filters with critical count <= 3' do
            is_expected.to contain_exactly(inventory_filter_2, inventory_filter_3)
          end
        end

        context 'with equal_to operator' do
          let(:operator) { 'equal_to' }

          it 'returns filters with critical count = 3' do
            is_expected.to contain_exactly(inventory_filter_3)
          end
        end
      end

      context 'with invalid severity' do
        let(:severity) { 'invalid_severity' }
        let(:operator) { 'equal_to' }
        let(:count) { 5 }

        it 'returns none' do
          is_expected.to be_empty
        end
      end

      context 'with invalid operator' do
        let(:severity) { 'critical' }
        let(:operator) { 'invalid_operator' }
        let(:count) { 5 }

        it 'returns none' do
          is_expected.to be_empty
        end
      end
    end

    describe '.by_analyzer_status' do
      subject { described_class.by_analyzer_status(analyzer_type, status) }

      context 'with valid analyzer type and status' do
        let(:analyzer_type) { 'sast' }

        context 'with success status' do
          let(:status) { 'success' }

          it 'returns filters with SAST success' do
            is_expected.to contain_exactly(inventory_filter_2)
          end
        end

        context 'with disabled status' do
          let(:status) { 'failed' }

          it 'returns filters with SAST disabled' do
            is_expected.to contain_exactly(inventory_filter_1)
          end
        end

        context 'with not_configured status' do
          let(:status) { 'not_configured' }

          it 'returns filters with SAST not configured' do
            is_expected.to contain_exactly(inventory_filter_3)
          end
        end
      end

      context 'with invalid analyzer type' do
        let(:analyzer_type) { 'invalid_analyzer' }
        let(:status) { 'success' }

        it 'returns none' do
          is_expected.to be_empty
        end
      end

      context 'with invalid status' do
        let(:analyzer_type) { 'sast' }
        let(:status) { 'invalid_status' }

        it 'returns none' do
          is_expected.to be_empty
        end
      end
    end

    describe '.order_by_project_id_asc' do
      subject { described_class.order_by_project_id_asc }

      it 'returns values in the correct order' do
        is_expected.to match_array([inventory_filter_1, inventory_filter_2, inventory_filter_3].sort_by(&:project_id))
      end
    end

    describe '.search' do
      subject { described_class.search(query) }

      context 'with exact match' do
        let(:query) { 'security-project' }

        it 'returns the matching filter' do
          is_expected.to contain_exactly(inventory_filter_1)
        end
      end

      context 'with partial match' do
        let(:query) { 'project' }

        it 'returns all filters containing the search term' do
          is_expected.to contain_exactly(inventory_filter_1, inventory_filter_2, inventory_filter_3)
        end
      end

      context 'with case insensitive match' do
        let(:query) { 'SECURITY' }

        it 'returns matching filters regardless of case' do
          is_expected.to contain_exactly(inventory_filter_1)
        end
      end

      context 'with no matches' do
        let(:query) { 'nonexistent' }

        it 'returns no filters' do
          is_expected.to be_empty
        end
      end
    end
  end
end
