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
    let_it_be(:group) { create(:group) }
    let_it_be(:project1) { create(:project, name: 'security-project', namespace: group) }
    let_it_be(:project2) { create(:project, name: 'another-project', namespace: group) }
    let_it_be(:project3) { create(:project, name: 'test-project', namespace: group) }

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

    describe 'security attribute scopes' do
      let_it_be(:security_category1) { create(:security_category, namespace: group, name: 'Environment') }
      let_it_be(:security_category2) { create(:security_category, namespace: group, name: 'Business Impact') }
      let_it_be(:attribute1) do
        create(:security_attribute, security_category: security_category1, namespace: group, name: 'Production')
      end

      let_it_be(:attribute2) do
        create(:security_attribute, security_category: security_category1, namespace: group, name: 'Staging')
      end

      let_it_be(:attribute3) do
        create(:security_attribute, security_category: security_category2, namespace: group, name: 'Critical')
      end

      let_it_be(:project1_attribute1) do
        create(:project_to_security_attribute,
          project: project1,
          security_attribute: attribute1,
          traversal_ids: project1.namespace.traversal_ids
        )
      end

      let_it_be(:project1_attribute3) do
        create(:project_to_security_attribute,
          project: project1,
          security_attribute: attribute3,
          traversal_ids: project1.namespace.traversal_ids
        )
      end

      let_it_be(:project2_attribute2) do
        create(:project_to_security_attribute,
          project: project2,
          security_attribute: attribute2,
          traversal_ids: project2.namespace.traversal_ids
        )
      end

      describe '.by_security_attributes' do
        subject { described_class.by_security_attributes(is_one_of_filters, is_not_one_of_filters) }

        let(:is_not_one_of_filters) { [] }

        context 'with empty filters' do
          let(:is_one_of_filters) { [] }

          it 'returns all filters' do
            is_expected.to be_empty
          end
        end

        context 'with IS_ONE_OF filters' do
          context 'with single filter containing single attribute' do
            let(:is_one_of_filters) { [[attribute1.id]] }

            it 'returns filters for projects with the specified attribute' do
              is_expected.to contain_exactly(inventory_filter_1)
            end
          end

          context 'with single filter containing multiple attributes' do
            let(:is_one_of_filters) { [[attribute1.id, attribute2.id]] } # OR logic

            it 'returns filters for projects with any of the specified attributes' do
              is_expected.to contain_exactly(inventory_filter_1, inventory_filter_2)
            end
          end

          context 'with multiple filters' do
            let(:is_one_of_filters) { [[attribute1.id], [attribute3.id]] } # AND logic

            it 'returns filters for projects with all specified attributes' do
              is_expected.to contain_exactly(inventory_filter_1)
            end
          end

          context 'with multiple filters where no project matches all' do
            let(:is_one_of_filters) { [[attribute1.id], [attribute2.id]] }

            it 'returns no filters' do
              is_expected.to be_empty
            end
          end

          context 'with non-existent attribute ID' do
            let(:is_one_of_filters) { [[non_existing_record_id]] }

            it 'returns no filters' do
              is_expected.to be_empty
            end
          end
        end

        context 'with IS_NOT_ONE_OF filters' do
          let(:is_one_of_filters) { [] }

          context 'with single filter containing single attribute' do
            let(:is_not_one_of_filters) { [[attribute1.id]] }

            it 'returns filters for projects without the specified attribute' do
              is_expected.to contain_exactly(inventory_filter_2, inventory_filter_3)
            end
          end

          context 'with single filter containing multiple attributes' do
            let(:is_not_one_of_filters) { [[attribute1.id, attribute2.id]] }

            it 'returns filters for projects without any of the specified attributes' do
              is_expected.to contain_exactly(inventory_filter_3)
            end
          end

          context 'with multiple filters' do
            let(:is_not_one_of_filters) { [[attribute1.id], [attribute3.id]] }

            it 'returns filters for projects without any of the specified attributes' do
              is_expected.to contain_exactly(inventory_filter_2, inventory_filter_3)
            end
          end

          context 'with non-existent attribute ID' do
            let(:is_not_one_of_filters) { [[non_existing_record_id]] }

            it 'returns all filters' do
              is_expected.to contain_exactly(inventory_filter_1, inventory_filter_2, inventory_filter_3)
            end
          end
        end

        context 'with combined IS_ONE_OF and IS_NOT_ONE_OF filters' do
          context 'with attribute inclusion and exclusion' do
            let(:is_one_of_filters) { [[attribute1.id]] }
            let(:is_not_one_of_filters) { [[attribute3.id]] }

            it 'returns filters for projects with included attributes but without excluded ones' do
              is_expected.to be_empty
            end
          end

          context 'with multiple inclusions and exclusions' do
            let(:is_one_of_filters) { [[attribute1.id, attribute2.id]] }
            let(:is_not_one_of_filters) { [[attribute3.id]] }

            it 'returns filters matching inclusion criteria without excluded attributes' do
              # project1 has attribute1 but also has attribute3 (excluded)
              # project2 has attribute2 and doesn't have attribute3
              is_expected.to contain_exactly(inventory_filter_2)
            end
          end

          context 'with complex AND logic in IS_ONE_OF and exclusions' do
            let(:is_one_of_filters) { [[attribute1.id], [attribute3.id]] }
            let(:is_not_one_of_filters) { [[attribute2.id]] }

            it 'returns filters for projects with any included attributes and without excluded ones' do
              # project1 has both attribute1 AND attribute3, and doesn't have attribute2
              is_expected.to contain_exactly(inventory_filter_1)
            end
          end
        end
      end
    end
  end
end
