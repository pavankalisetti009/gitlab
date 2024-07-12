# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Weight, feature_category: :team_planning do
  describe '.quick_action_params' do
    subject { described_class.quick_action_params }

    it { is_expected.to include(:weight) }
  end

  context 'with weight widget definition' do
    let_it_be(:work_item, refind: true) { create(:work_item, :issue, weight: 5) }

    before_all do
      WorkItems::WidgetDefinition.delete_all
    end

    before do
      create(
        :widget_definition, :default,
        work_item_type: work_item.work_item_type, widget_type: 'weight',
        widget_options: widget_options
      )
    end

    describe '#weight' do
      subject(:weight) { work_item.get_widget(:weight).weight }

      context 'when work item does not support editable weight' do
        let(:widget_options) { { editable: false, rollup: false } }

        it 'returns nil' do
          expect(weight).to be_nil
        end
      end

      context 'when work item supports editable weight' do
        let(:widget_options) { { editable: true, rollup: false } }

        it 'returns the work item weight value' do
          expect(weight).to eq(work_item.weight)
        end
      end
    end

    describe '#rolled_up_weight' do
      subject(:rolled_up_weight) { work_item.get_widget(:weight).rolled_up_weight }

      context 'when work item does not support rolled up weight' do
        let(:widget_options) { { editable: false, rollup: false } }

        it 'returns nil' do
          expect(rolled_up_weight).to be_nil
        end
      end

      context 'when work item supports rolled up weight' do
        let(:widget_options) { { editable: false, rollup: true } }

        it 'returns 0' do
          expect(rolled_up_weight).to eq(0)
        end
      end
    end
  end
end
