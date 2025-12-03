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

        expect(result.map(&:base_type)).to match_array(%w[task incident ticket])
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

  describe '#allowed_child_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:task_type) { build(:work_item_system_defined_type, :task) }

    context 'without authorization' do
      it 'returns all allowed child types without license checks' do
        # Assuming issue can have tasks as children
        expect(issue_type.allowed_child_types(authorize: false)).to include(task_type)
      end

      it 'returns child types ordered by name' do
        child_types = issue_type.allowed_child_types(authorize: false)
        expect(child_types).to eq(child_types.sort_by { |t| t.name.downcase })
      end
    end

    context 'with authorization' do
      context 'when resource_parent is a project' do
        context 'with epics license' do
          before do
            stub_licensed_features(epics: true)
          end

          it 'includes epic as child type when licensed' do
            # Assuming epic can have issues as children
            child_types = epic_type.allowed_child_types(
              authorize: true,
              resource_parent: project
            )

            expect(child_types).to include(issue_type)
          end
        end

        context 'without epics license' do
          before do
            stub_licensed_features(epics: false)
          end

          it 'excludes epic from child types when not licensed' do
            # If issue type has epic as a potential child
            child_types = issue_type.allowed_child_types(
              authorize: true,
              resource_parent: project
            )

            expect(child_types).not_to include(epic_type)
          end
        end
      end

      context 'when resource_parent is a group' do
        context 'with subepics license' do
          before do
            stub_licensed_features(subepics: true)
          end

          it 'includes epic as child type for epic when licensed' do
            # Epic can have sub-epics
            child_types = epic_type.allowed_child_types(
              authorize: true,
              resource_parent: group
            )

            expect(child_types).to include(epic_type)
          end
        end

        context 'without subepics license' do
          before do
            stub_licensed_features(subepics: false)
          end

          it 'excludes epic as child type for epic when not licensed' do
            child_types = epic_type.allowed_child_types(
              authorize: true,
              resource_parent: group
            )

            expect(child_types).not_to include(epic_type)
          end
        end
      end

      context 'when resource_parent is nil' do
        it 'returns types without license validation' do
          child_types = issue_type.allowed_child_types(
            authorize: true,
            resource_parent: nil
          )

          # Should behave like authorize: false
          expect(child_types).to eq(issue_type.allowed_child_types(authorize: false))
        end
      end

      context 'with multiple licensed types' do
        let(:objective_type) { build(:work_item_system_defined_type, :objective) }
        let(:key_result_type) { build(:work_item_system_defined_type, :key_result) }

        before do
          stub_licensed_features(okrs: true)
        end

        it 'includes all licensed child types' do
          # Assuming objective can have key_results as children
          child_types = objective_type.allowed_child_types(
            authorize: true,
            resource_parent: project
          )

          expect(child_types).to include(key_result_type)
        end
      end
    end
  end

  describe '#allowed_parent_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:task_type) { build(:work_item_system_defined_type, :task) }

    context 'without authorization' do
      it 'returns all allowed parent types without license checks' do
        # Assuming task can have issue as parent
        expect(task_type.allowed_parent_types(authorize: false))
          .to include(issue_type)
      end

      it 'returns parent types ordered by name' do
        parent_types = task_type.allowed_parent_types(authorize: false)
        expect(parent_types).to eq(parent_types.sort_by { |t| t.name.downcase })
      end
    end

    context 'with authorization' do
      context 'when resource_parent is a project' do
        context 'with epics license' do
          before do
            stub_licensed_features(epics: true)
          end

          it 'includes epic as parent type when licensed' do
            # Assuming issue can have epic as parent
            parent_types = issue_type.allowed_parent_types(
              authorize: true,
              resource_parent: project
            )

            expect(parent_types).to include(epic_type)
          end
        end

        context 'without epics license' do
          before do
            stub_licensed_features(epics: false)
          end

          it 'excludes epic from parent types when not licensed' do
            parent_types = issue_type.allowed_parent_types(
              authorize: true,
              resource_parent: project
            )

            expect(parent_types).not_to include(epic_type)
          end
        end

        context 'with type without license' do
          it 'includes types regardless of license' do
            # Task should always be allowed as parent for subtasks if configured
            parent_types = task_type.allowed_parent_types(
              authorize: true,
              resource_parent: project
            )

            expect(parent_types.map(&:base_type)).to include('issue')
          end
        end
      end

      context 'when resource_parent is a group' do
        context 'with subepics license' do
          before do
            stub_licensed_features(subepics: true)
          end

          it 'includes epic as parent type for epic when licensed' do
            # Epic can have parent epics
            parent_types = epic_type.allowed_parent_types(
              authorize: true,
              resource_parent: group
            )

            expect(parent_types).to include(epic_type)
          end
        end

        context 'without subepics license' do
          before do
            stub_licensed_features(subepics: false)
          end

          it 'excludes epic as parent type for epic when not licensed' do
            parent_types = epic_type.allowed_parent_types(
              authorize: true,
              resource_parent: group
            )

            expect(parent_types).not_to include(epic_type)
          end
        end
      end

      context 'when resource_parent is nil' do
        it 'returns types without license validation' do
          parent_types = task_type.allowed_parent_types(
            authorize: true,
            resource_parent: nil
          )

          # Should behave like authorize: false
          expect(parent_types).to eq(task_type.allowed_parent_types(authorize: false))
        end
      end
    end
  end

  describe '#widgets' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }

    context 'with project as resource_parent' do
      context 'when all licensed features are available' do
        before do
          stub_licensed_features(
            iterations: true,
            issue_weights: true,
            issuable_health_status: true,
            okrs: true,
            epic_colors: true,
            custom_fields: true,
            security_dashboard: true,
            work_item_status: true,
            requirements: true
          )
        end

        it 'includes widgets from the super method' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          # Should include both CE and EE widgets
          expect(widget_types).to include('assignees', 'description', 'labels')
        end

        it 'includes licensed widgets when licenses are available' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('vulnerabilities', 'weight', 'health_status')
        end
      end

      context 'when some licensed features are not available' do
        before do
          stub_licensed_features(
            issue_weights: true,
            issuable_health_status: false,
            custom_fields: false,
            work_item_status: false
          )
        end

        it 'excludes widgets that require unavailable licenses' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).not_to include('status', 'health_status', 'custom_fields')
        end

        it 'includes widgets with available licenses' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('weight')
        end

        it 'includes CE widgets that do not require licenses' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('assignees', 'description', 'labels', 'milestone')
        end
      end
    end

    context 'with group as resource_parent' do
      context 'when licensed features are available' do
        before do
          stub_licensed_features(
            issuable_health_status: true,
            issue_weights: true,
            epics: true
          )
        end

        it 'includes licensed widgets for group' do
          widgets = epic_type.widgets(group)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('health_status', 'weight')
        end

        it 'includes CE widgets' do
          widgets = epic_type.widgets(group)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('description', 'labels')
        end
      end

      context 'when licensed features are not available' do
        before do
          stub_licensed_features(
            iterations: false,
            issue_weights: false
          )
        end

        it 'excludes unlicensed widgets' do
          widgets = epic_type.widgets(group)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).not_to include('iteration', 'weight')
        end
      end
    end
  end
end
