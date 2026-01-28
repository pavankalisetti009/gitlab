# frozen_string_literal: true

module WorkItems
  module WidgetHelpers
    # Stubs one or more widgets for a single work item instance.
    # This mocks the get_widget method to return false for disabled widgets,
    # simulating that the work item doesn't have those widgets available.
    #
    # Examples:
    #   stub_work_item_widget(work_item, notes: false)
    #   stub_work_item_widget(work_item, labels: false, assignees: false, milestone: false)
    #   stub_work_item_widget(work_item, notes: true)
    #
    # Note: The enabled: true case doesn't fully work yet - it tries to return
    # the original widget but may not be useful if the type doesn't have it.
    # This can be improved in future iterations.
    def stub_work_item_widget(work_item, **widgets)
      widgets.each do |widget, enabled|
        allow(work_item).to receive(:get_widget).and_call_original
        allow(work_item).to receive(:get_widget).with(widget).and_return(enabled ? work_item.get_widget(widget) : false)
      end
    end

    # Stubs one or more widgets for all work item instances via allow_any_instance_of.
    # This is useful for testing behavior when widgets are not available across all work items.
    # Also handles Issue instances which may use has_widget? instead of get_widget.
    #
    # Examples:
    #   stub_all_work_item_widgets(notes: false)
    #   stub_all_work_item_widgets(labels: false, assignees: false, milestone: false)
    #   stub_all_work_item_widgets(notes: true)
    def stub_all_work_item_widgets(**widgets)
      widgets.each do |widget, enabled|
        next if enabled

        # rubocop:disable RSpec/AnyInstanceOf -- To simulate work item without weight widget
        allow_any_instance_of(WorkItem).to receive(:get_widget).and_call_original
        allow_any_instance_of(WorkItem).to receive(:get_widget).with(widget).and_return(false)
        allow_any_instance_of(Issue).to receive(:has_widget?).with(widget).and_return(false)
        # rubocop:enable RSpec/AnyInstanceOf
      end
    end
  end
end
