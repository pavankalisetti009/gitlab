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

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end
end
