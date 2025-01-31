# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Type, feature_category: :team_planning do
  describe '#widgets' do
    let_it_be(:group) { build_stubbed(:group) }
    let_it_be(:project) { build_stubbed(:project, group: group) }
    let_it_be_with_refind(:work_item_type) { create(:work_item_type) }
    let(:licensed_features) { WorkItems::Type::LICENSED_WIDGETS.keys }
    let(:disabled_features) { [] }

    before_all do
      # All possible default work item types already exist on the DB. So we find the first one, remove all existing
      # widgets and then add all existing ones. This type now has all possible widgets just for testing.
      WorkItems::WidgetDefinition.where(work_item_type: work_item_type).delete_all
      WorkItems::WidgetDefinition.widget_types.each_key do |type|
        create(:widget_definition, work_item_type: work_item_type, name: type.to_s, widget_type: type)
      end
    end

    shared_examples 'work_item_type returning only licensed widgets' do
      let(:feature) { feature_widget.first }
      let(:widget_classes) { feature_widget.last }

      subject(:returned_widgets) { work_item_type.widgets(parent) }

      context 'when feature is available' do
        it 'returns the associated licensesd widget' do
          widget_classes.each do |widget|
            expect(returned_widgets.map(&:widget_class)).to include(widget)
          end
        end
      end

      context 'when feature is not available' do
        let(:disabled_features) { [feature] }

        it 'does not return the unlincensed widgets' do
          widget_classes.each do |widget|
            expect(returned_widgets.map(&:widget_class)).not_to include(widget)
          end
        end
      end

      context 'when type is epic' do
        let_it_be_with_refind(:work_item_type) { create(:work_item_type, :epic) }

        context 'when work_items_beta is enabled' do
          it 'returns Assignees widget' do
            expect(returned_widgets.map(&:widget_class)).to include(::WorkItems::Widgets::Assignees)
          end
        end

        context 'when work_items_beta is disabled' do
          before do
            stub_feature_flags(work_items_beta: false)
          end

          it 'does not return Assignees widget' do
            expect(returned_widgets.map(&:widget_class)).not_to include(::WorkItems::Widgets::Assignees)
          end
        end
      end

      context 'when custom_fields_feature is disabled' do
        before do
          stub_feature_flags(custom_fields_feature: false)
        end

        it 'does not return custom fields widget' do
          expect(returned_widgets.map(&:widget_class)).not_to include(::WorkItems::Widgets::CustomFields)
        end
      end
    end

    where(feature_widget: WorkItems::Type::LICENSED_WIDGETS.transform_values { |v| Array(v) }.to_a)

    with_them do
      before do
        stub_licensed_features(**feature_hash)
      end

      context 'when parent is a group' do
        let(:parent) { group }

        it_behaves_like 'work_item_type returning only licensed widgets'
      end

      context 'when parent is a project' do
        let(:parent) { project }

        it_behaves_like 'work_item_type returning only licensed widgets'
      end
    end
  end

  describe '.allowed_group_level_types' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_group) }

    subject { described_class.allowed_group_level_types(group) }

    context 'when epic license is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'returns supported types at group level' do
        is_expected.to contain_exactly(*described_class.base_types.keys)
      end

      context 'when create_group_level_work_items is disabled and work_item_epics is enabled' do
        before do
          stub_feature_flags(create_group_level_work_items: false, work_item_epics: root_group)
        end

        it { is_expected.to contain_exactly('epic') }
      end

      context 'when create_group_level_work_items is enabled and work_item_epics is disabled' do
        before do
          stub_feature_flags(create_group_level_work_items: true, work_item_epics: false)
        end

        it { is_expected.to contain_exactly(*described_class.base_types.keys.excluding('epic')) }
      end

      context 'when create_group_level_work_items is disabled and work_item_epics is disabled' do
        before do
          stub_feature_flags(create_group_level_work_items: false, work_item_epics: false)
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when epic license is not available' do
      before do
        stub_licensed_features(epics: false)
      end

      it { is_expected.to contain_exactly(*described_class.base_types.keys.excluding('epic')) }

      context 'when create_group_level_work_items is disabled' do
        before do
          stub_feature_flags(create_group_level_work_items: false, work_item_epics: false)
        end

        it { is_expected.to be_empty }
      end
    end
  end

  describe '#supported_conversion_types' do
    let_it_be(:resource_parent) { create(:project) }
    let_it_be(:issue_type) { create(:work_item_type, :issue) }
    let(:work_item_type) { issue_type }

    shared_examples 'licensed type availability' do |type, licensed_feature|
      let_it_be(:wi_type) { create(:work_item_type, type.to_sym) }

      context "when #{licensed_feature} is available" do
        before do
          stub_licensed_features(licensed_feature => true)
        end

        it "returns #{type} type in the supported types" do
          expect(work_item_type.supported_conversion_types(resource_parent)).to include(wi_type)
        end
      end

      context "when #{licensed_feature} is unavailable" do
        before do
          stub_licensed_features(licensed_feature => false)
        end

        it "does not return #{type} type in the supported types" do
          expect(work_item_type.supported_conversion_types(resource_parent)).not_to include(wi_type)
        end
      end
    end

    shared_examples 'okrs types not included' do
      it 'does not return Objective and Key Result types in the supported types' do
        expect(work_item_type.supported_conversion_types(resource_parent))
          .not_to include(objective, key_result)
      end
    end

    WorkItems::Type::LICENSED_TYPES.each do |type, licensed_feature|
      it_behaves_like 'licensed type availability', type, licensed_feature
    end

    context 'when okrs_mvc is disabled' do
      let_it_be(:objective) { create(:work_item_type, :objective) }
      let_it_be(:key_result) { create(:work_item_type, :key_result) }

      before do
        stub_feature_flags(okrs_mvc: false)
      end

      it_behaves_like 'okrs types not included'

      context 'when resource parent is group' do
        let_it_be(:resource_parent) { resource_parent.reload.project_namespace }

        it_behaves_like 'okrs types not included'
      end
    end

    context 'when work_item_epics is disabled' do
      let_it_be(:epic) { create(:work_item_type, :epic) }

      before do
        stub_feature_flags(work_item_epics: false)
        stub_licensed_features(epics: true)
      end

      it "does not return epic type in the supported types" do
        expect(work_item_type.supported_conversion_types(resource_parent)).not_to include(epic)
      end
    end
  end

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end
end
