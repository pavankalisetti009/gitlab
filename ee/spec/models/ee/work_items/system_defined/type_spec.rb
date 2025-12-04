# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::SystemDefined::Type, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  describe '.fixed_items' do
    it 'defines all expected work item types' do
      expect(described_class.fixed_items.size).to eq(9)
    end

    it 'includes Epic type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 8 }

      expect(type).to include(
        id: 8,
        name: 'Epic',
        base_type: 'epic',
        icon_name: 'work-item-epic'
      )
    end

    it 'includes Key Result type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 7 }

      expect(type).to include(
        id: 7,
        name: 'Key Result',
        base_type: 'key_result',
        icon_name: 'work-item-keyresult'
      )
    end

    it 'includes Objective type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 6 }

      expect(type).to include(
        id: 6,
        name: 'Objective',
        base_type: 'objective',
        icon_name: 'work-item-objective'
      )
    end

    it 'includes Requirement type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 4 }

      expect(type).to include(
        id: 4,
        name: 'Requirement',
        base_type: 'requirement',
        icon_name: 'work-item-requirement'
      )
    end

    it 'includes Test Case type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 3 }

      expect(type).to include(
        id: 3,
        name: 'Test Case',
        base_type: 'test_case',
        icon_name: 'work-item-test-case'
      )
    end

    it 'has unique IDs for all types' do
      ids = described_class.fixed_items.pluck(:id)

      expect(ids.uniq.size).to eq(ids.size)
    end

    it 'has unique base_types for all types' do
      base_types = described_class.fixed_items.pluck(:base_type)

      expect(base_types.uniq.size).to eq(base_types.size)
    end
  end

  describe '#supported_conversion_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:objective_type) { build(:work_item_system_defined_type, :objective) }
    let(:key_result_type) { build(:work_item_system_defined_type, :key_result) }
    let(:requirement_type) { build(:work_item_system_defined_type, :requirement) }

    context 'with group as resource_parent' do
      let(:resource_parent) { group }

      context 'when all licensed features are available' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          resource_parent.add_developer(user)
        end

        it 'includes all types except the current type' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include('epic', 'requirement', 'task', 'incident', 'ticket')
          expect(result.map(&:base_type)).not_to include('issue')
        end

        it 'orders results by name' do
          result = issue_type.supported_conversion_types(resource_parent, user)
          names = result.map(&:name)

          expect(names).to eq(names.sort_by(&:downcase))
        end
      end

      shared_examples 'when license is not available' do
        before do
          resource_parent.add_developer(user)
        end

        it 'excludes the type' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include(*excluded_types)
        end

        it 'includes other licensed types' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include(*included_types)
        end
      end

      context 'when epics license is not available' do
        before do
          stub_licensed_features(epics: false, okrs: true, requirements: true)
        end

        let(:excluded_types) { ['epic'] }
        let(:included_types) { %w[requirement] }

        it_behaves_like 'when license is not available'
      end

      context 'when requirements license is not available' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: false)
        end

        let(:excluded_types) { %w[requirement] }
        let(:included_types) { %w[epic] }

        it_behaves_like 'when license is not available'
      end

      context 'when user cannot create epics' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          # User is not a member, so cannot create epics
        end

        it 'excludes epic type even if licensed' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include('epic')
        end

        it 'includes other types that do not require special permissions' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include('requirement')
        end
      end
    end

    shared_examples "for objective and key result" do
      before_all do
        group.add_developer(user)
      end

      context 'when okrs_mvc feature flag is enabled' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          stub_feature_flags(okrs_mvc: project)
        end

        it 'includes objective and key_result types' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include('objective', 'key_result')
        end
      end

      context 'when okrs_mvc feature flag is disabled' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          stub_feature_flags(okrs_mvc: false)
        end

        it 'excludes objective and key_result types even if licensed' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include('objective', 'key_result')
        end

        it 'includes other licensed types' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include('epic', 'requirement')
        end
      end
    end

    context 'with project as resource_parent' do
      let(:resource_parent) { project }

      it_behaves_like "for objective and key result"
    end

    context 'with project namespace as resource_parent' do
      let(:resource_parent) { project.project_namespace }

      it_behaves_like "for objective and key result"
    end

    context 'with no licensed features' do
      before do
        stub_licensed_features(epics: false, okrs: false, requirements: false)
      end

      it 'returns only CE types' do
        result = issue_type.supported_conversion_types(project, user)

        expect(result.map(&:base_type)).to match_array(%w[task incident ticket test_case])
      end
    end
  end

  describe '#descendant_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:task_type) { build(:work_item_system_defined_type, :task) }

    context 'with EE hierarchy including epics' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      it 'includes all child types' do
        descendants = epic_type.descendant_types

        # This will depend on your actual hierarchy configuration
        expect(descendants).to match_array([epic_type, issue_type, task_type])
      end
    end

    context 'with circular dependencies in EE types' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      it 'handles circular epic → epic relationships' do
        # If epic can be parent and child of epic (with subepics)
        descendants = epic_type.descendant_types

        # Should not cause infinite loop
        expect { descendants }.not_to raise_error
      end

      it 'returns unique descendants only once' do
        descendants = epic_type.descendant_types

        # Check for uniqueness
        expect(descendants.uniq.size).to eq(descendants.size)
      end
    end
  end

  describe '#authorized_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:resource_parent) { project }

    context 'for issue parent types' do
      let(:parent_types) { [epic_type] }

      context 'when epics license is available' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'includes epic as authorized parent' do
          result = issue_type.send(:authorized_types, parent_types, resource_parent, :parent)

          expect(result).to include(epic_type)
        end
      end

      context 'when epics license is not available' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'excludes epic as authorized parent' do
          result = issue_type.send(:authorized_types, parent_types, resource_parent, :parent)

          expect(result).not_to include(epic_type)
        end
      end
    end

    context 'for epic child types' do
      let(:child_types) { [issue_type, epic_type] }

      context 'when both epics and subepics licenses are available' do
        before do
          stub_licensed_features(epics: true, subepics: true)
        end

        it 'includes both issue and epic as authorized children' do
          result = epic_type.send(:authorized_types, child_types, resource_parent, :child)

          expect(result).to include(issue_type, epic_type)
        end
      end

      context 'when epics license is available but subepics is not' do
        before do
          stub_licensed_features(epics: true, subepics: false)
        end

        it 'includes issue but excludes epic as authorized child' do
          result = epic_type.send(:authorized_types, child_types, resource_parent, :child)

          expect(result).to include(issue_type)
          expect(result).not_to include(epic_type)
        end
      end
    end

    context 'for types without licensed hierarchy restrictions' do
      let(:task_type) { build(:work_item_system_defined_type, :task) }
      let(:ticket_type) { build(:work_item_system_defined_type, :ticket) }
      let(:child_types) { [issue_type, task_type, ticket_type] }

      before do
        stub_licensed_features(epics: true)
      end

      it 'includes types without license restrictions' do
        result = epic_type.send(:authorized_types, child_types, resource_parent, :child)

        # Task and Ticket don't have license restrictions in LICENSED_HIERARCHY_TYPES
        # so they should be included (the `next type unless license_name` branch)
        expect(result).to include(task_type, ticket_type)
      end

      it 'filters licensed types correctly while keeping unlicensed types' do
        stub_licensed_features(epics: false) # Disable epics license

        result = epic_type.send(:authorized_types, child_types, resource_parent, :child)

        # Issue requires epics license, so it should be excluded
        expect(result).not_to include(issue_type)
        # Task and Ticket have no license requirements, so they should be included
        expect(result).to include(task_type, ticket_type)
      end
    end

    context 'when resource_parent is nil' do
      let(:parent_types) { [epic_type] }

      it 'excludes licensed types when resource_parent is nil' do
        result = issue_type.send(:authorized_types, parent_types, nil, :parent)

        expect(result).not_to include(epic_type)
      end
    end
  end
end
