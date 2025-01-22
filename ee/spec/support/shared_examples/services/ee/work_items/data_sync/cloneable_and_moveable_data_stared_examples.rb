# frozen_string_literal: true

RSpec.shared_examples 'cloneable and moveable for ee widget data' do
  def work_item_weights_source(work_item)
    work_item.reload.weights_source&.slice(:rolled_up_weight, :rolled_up_completed_weight)
  end

  def work_item_epic(work_item)
    work_item.reload.epic
  end

  def work_item_vulnerabilities(work_item)
    work_item.reload.related_vulnerabilities
  end

  let_it_be(:weights_source) do
    weights_source = create(:work_item_weights_source, work_item: original_work_item, rolled_up_weight: 20,
      rolled_up_completed_weight: 50)
    weights_source&.slice(:rolled_up_weight, :rolled_up_completed_weight)
  end

  let_it_be(:epic) do
    epic = create(:epic, :with_work_item_parent)
    parent_link = create(:parent_link, work_item: original_work_item, work_item_parent: epic.work_item)
    create(:epic_issue, issue: original_work_item, epic: epic, work_item_parent_link: parent_link)
    epic
  end

  let_it_be(:related_vulnerabilities) do
    vulnerability_links = create_list(:vulnerabilities_issue_link, 2, issue: original_work_item)
    vulnerability_links.map(&:vulnerability)
  end

  let_it_be(:move) { WorkItems::DataSync::MoveService }
  let_it_be(:clone) { WorkItems::DataSync::CloneService }

  # rubocop: disable Layout/LineLength -- improved readability with one line per widget
  let_it_be(:widgets) do
    [
      { widget_name: :weights_source,          eval_value: :work_item_weights_source,  expected_data: weights_source,          operations: [move, clone] },
      # these are non widget associations, but we can test these the same way
      { widget_name: :related_vulnerabilities, eval_value: :work_item_vulnerabilities, expected_data: related_vulnerabilities, operations: [move] },
      # for hierarchy widget, ensure that epic(though epic_issue) is being copied to the new work item
      { widget_name: :epic,                    eval_value: :work_item_epic,            expected_data: epic,                    operations: [move, clone] }
    ]
  end
  # rubocop: enable Layout/LineLength

  context "with widget" do
    it_behaves_like 'for clone and move services'
  end
end
