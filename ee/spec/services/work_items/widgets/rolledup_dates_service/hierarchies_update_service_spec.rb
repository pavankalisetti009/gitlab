# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
  :aggregate_failures,
  feature_category: :team_planning do
    let_it_be(:group) { create(:group) }
    let_it_be(:start_date) { 1.day.ago.to_date }
    let_it_be(:due_date) { 1.day.from_now.to_date }

    let_it_be_with_reload(:milestone) do
      create(:milestone, group: group, start_date: start_date, due_date: due_date)
    end

    let_it_be(:work_item_1) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    let_it_be(:work_item_2) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    let_it_be(:work_item_fixed_dates) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_items_dates_source, work_item: parent, start_date_is_fixed: true, due_date_is_fixed: true)
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    let_it_be_with_reload(:epic_1) { create(:epic, group: group, work_item: work_item_1) }
    let_it_be_with_reload(:epic_2) { create(:epic, group: group, work_item: work_item_2) }

    subject(:service) do
      described_class.new(WorkItem.id_in([
        work_item_1.id,
        work_item_2.id,
        work_item_fixed_dates.id
      ]))
    end

    shared_examples 'syncs work item dates sources to epics' do
      specify do
        service.execute

        epic_1.reload
        work_item_1.dates_source.reload
        expect(epic_1.start_date)
          .to eq(work_item_1.dates_source.start_date)
        expect(epic_1.start_date_fixed)
          .to eq(work_item_1.dates_source.start_date_fixed)
        expect(epic_1.start_date_is_fixed || false)
          .to eq(work_item_1.dates_source.start_date_is_fixed)
        expect(epic_1.start_date_sourcing_milestone_id)
          .to eq(work_item_1.dates_source.start_date_sourcing_milestone_id)
        expect(epic_1.start_date_sourcing_epic_id)
          .to eq(work_item_1.dates_source.start_date_sourcing_work_item&.sync_object&.id)
        expect(epic_1.due_date)
          .to eq(work_item_1.dates_source.due_date)
        expect(epic_1.due_date_fixed)
          .to eq(work_item_1.dates_source.due_date_fixed)
        expect(epic_1.due_date_is_fixed || false)
          .to eq(work_item_1.dates_source.due_date_is_fixed)
        expect(epic_1.due_date_sourcing_milestone_id)
          .to eq(work_item_1.dates_source.due_date_sourcing_milestone_id)
        expect(epic_1.due_date_sourcing_epic_id)
          .to eq(work_item_1.dates_source.due_date_sourcing_work_item&.sync_object&.id)

        epic_2.reload
        work_item_2.dates_source.reload
        expect(epic_2.start_date)
          .to eq(work_item_2.dates_source.start_date)
        expect(epic_2.start_date_fixed)
          .to eq(work_item_2.dates_source.start_date_fixed)
        expect(epic_2.start_date_is_fixed || false)
          .to eq(work_item_2.dates_source.start_date_is_fixed)
        expect(epic_2.start_date_sourcing_milestone_id)
          .to eq(work_item_2.dates_source.start_date_sourcing_milestone_id)
        expect(epic_2.start_date_sourcing_epic_id)
          .to eq(work_item_2.dates_source.start_date_sourcing_work_item&.sync_object&.id)
        expect(epic_2.due_date)
          .to eq(work_item_2.dates_source.due_date)
        expect(epic_2.due_date_fixed)
          .to eq(work_item_2.dates_source.due_date_fixed)
        expect(epic_2.due_date_is_fixed || false)
          .to eq(work_item_2.dates_source.due_date_is_fixed)
        expect(epic_2.due_date_sourcing_milestone_id)
          .to eq(work_item_2.dates_source.due_date_sourcing_milestone_id)
        expect(epic_2.due_date_sourcing_epic_id)
          .to eq(work_item_2.dates_source.due_date_sourcing_work_item&.sync_object&.id)
      end
    end

    it "enqueues the parent epic update" do
      parent = create(:work_item, :epic, namespace: group).tap do |parent|
        create(:parent_link, work_item: work_item_1, work_item_parent: parent)
      end

      expect(::WorkItems::RolledupDates::UpdateMultipleRolledupDatesWorker)
        .to receive(:perform_async)
        .with([parent.id])

      service.execute
    end

    it "updates the start_date and due_date from milestone" do
      expect { service.execute }
        .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
        .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
        .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
        .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
        .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
        .and not_change { work_item_fixed_dates.dates_source&.due_date }
    end

    include_examples 'syncs work item dates sources to epics'

    context "and the minimal start date comes from a child work_item" do
      let_it_be(:earliest_start_date) { start_date - 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group, start_date: earliest_start_date).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(earliest_start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end

    context "and the maximum due date comes from a child work_item" do
      let_it_be(:latest_due_date) { due_date + 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group, due_date: latest_due_date).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(latest_due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end

    context "and the minimal start date comes from a child work_item's dates_source" do
      let_it_be(:earliest_start_date) { start_date - 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group) do |work_item|
          create(:work_items_dates_source, :fixed, work_item: work_item, start_date: earliest_start_date)
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(earliest_start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end

    context "and the maximum due date comes from a child work_item's dates_source" do
      let_it_be(:latest_due_date) { due_date + 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group).tap do |work_item|
          create(:work_items_dates_source, :fixed, work_item: work_item, due_date: latest_due_date)
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(latest_due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end
  end
