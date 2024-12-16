# frozen_string_literal: true

RSpec.shared_examples 'cloneable and moveable for ee widget data' do
  def work_item_weights_source(work_item)
    work_item.reload.weights_source&.slice(:rolled_up_weight, :rolled_up_completed_weight)
  end

  let_it_be(:weights_source) do
    weights_source = create(:work_item_weights_source, work_item: original_work_item, rolled_up_weight: 20,
      rolled_up_completed_weight: 50)
    weights_source&.slice(:rolled_up_weight, :rolled_up_completed_weight)
  end

  let_it_be(:move) { WorkItems::DataSync::MoveService }
  let_it_be(:clone) { WorkItems::DataSync::CloneService }

  # rubocop: disable Layout/LineLength -- improved readability with one line per widget
  let_it_be(:widgets) do
    [
      { widget_name: :weights_source, eval_value: :work_item_weights_source, expected_data: weights_source, operations: [move, clone] }
    ]
  end
  # rubocop: enable Layout/LineLength

  with_them do
    context "with widget" do
      it_behaves_like 'for clone and move services'
    end
  end
end
