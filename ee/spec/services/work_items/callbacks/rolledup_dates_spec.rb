# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::Callbacks::RolledupDates, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }

  let(:start_date) { 1.day.ago.to_date }
  let(:due_date) { 1.day.from_now.to_date }
  let(:params) { { start_date: start_date, due_date: due_date } }

  let(:callback) { described_class.new(issuable: work_item, current_user: user, params: params) }

  before do
    allow(::WorkItems::Callbacks::RolledupDates::AttributesBuilder)
      .to receive(:build)
      .and_return(
        start_date: start_date,
        start_date_fixed: start_date,
        start_date_is_fixed: true,
        due_date: due_date,
        due_date_fixed: due_date,
        due_date_is_fixed: true)

    stub_licensed_features(epics: true)
  end

  describe '#after_save' do
    context "when dates source does not exist" do
      it "creates the work_item dates_souce and populates it" do
        expect { callback.after_save }
          .to change { WorkItems::DatesSource.count }

        dates_source = work_item.dates_source
        expect(dates_source.start_date).to eq(start_date)
        expect(dates_source.start_date_is_fixed).to eq(true)
        expect(dates_source.due_date).to eq(due_date)
        expect(dates_source.due_date_is_fixed).to eq(true)
      end
    end

    context "when dates source already exists" do
      let(:existing_start_date) { 2.days.ago.to_date }
      let(:existing_due_date) { 2.days.from_now.to_date }

      before do
        create(
          :work_items_dates_source,
          work_item: work_item,
          start_date: existing_start_date,
          start_date_fixed: existing_start_date,
          due_date: existing_due_date,
          due_date_fixed: existing_due_date)
      end

      it "updates the work_item dates_souce and populates it" do
        callback.after_save

        dates_source = work_item.dates_source
        expect(dates_source.start_date).to eq(start_date)
        expect(dates_source.start_date_is_fixed).to eq(true)
        expect(dates_source.due_date).to eq(due_date)
        expect(dates_source.due_date_is_fixed).to eq(true)
      end
    end
  end

  describe '#after_update_commit' do
    it 'rolls up the dates' do
      work_items = WorkItem.id_in(work_item.id)

      expect_next_instance_of(
        ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
        work_items
      ) do |service|
        expect(service).to receive(:execute)
      end

      callback.after_update_commit
    end
  end
end
