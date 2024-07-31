# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::Callbacks::RolledupDates::AttributesBuilder, feature_category: :portfolio_management do
  let_it_be_with_reload(:work_item) { create(:work_item, :epic) }

  let(:start_date) { 1.day.ago.to_date }
  let(:due_date) { 1.day.from_now.to_date }
  let(:milestone) { instance_double(::Milestone, id: 1, start_date: start_date - 1.day, due_date: due_date + 1.day) }

  def query_attributes_with(values)
    {
      due_date: nil,
      due_date_is_fixed: nil,
      due_date_sourcing_milestone_id: nil,
      due_date_sourcing_work_item_id: nil,
      start_date: nil,
      start_date_is_fixed: nil,
      start_date_sourcing_milestone_id: nil,
      start_date_sourcing_work_item_id: nil
    }.merge(values)
  end

  before do
    allow_next_instance_of(WorkItems::Widgets::RolledupDatesFinder) do |finder|
      allow(finder)
        .to receive(:attributes_for)
        .with(:start_date)
        .and_return(query_attributes_with(
          start_date: milestone.start_date,
          start_date_sourcing_milestone_id: milestone.id
        ))

      allow(finder)
        .to receive(:attributes_for)
        .with(:due_date)
        .and_return(query_attributes_with(
          due_date: milestone.due_date,
          due_date_sourcing_milestone_id: milestone.id
        ))
    end
  end

  subject(:builder) { described_class.new(work_item, params) }

  describe "#build" do
    context "when updating start_date" do
      context "when params[:start_date_is_fixed] is true" do
        context "when params[:start_date_fixed] is not provided" do
          let(:params) { { start_date_is_fixed: true } }

          it "does not set start_date and start_date_fixed values" do
            expect(builder.build).to eq(
              start_date_is_fixed: true
            )
          end
        end

        context "when params[:start_date_fixed] is provided" do
          let(:params) { { start_date_is_fixed: true, start_date_fixed: start_date } }

          it "sets the start_date and start_date_fixed to the given value" do
            expect(builder.build).to eq(
              start_date: start_date,
              start_date_fixed: start_date,
              start_date_is_fixed: true
            )
          end

          context "when params[:start_date_fixed] is nil and start_date_is_fixed is false" do
            let(:params) { { start_date_is_fixed: false, start_date_fixed: nil } }

            it "sets the start_date and start_date_fixed to nil" do
              expect(builder.build).to eq(
                start_date_is_fixed: false,
                start_date_fixed: nil,
                start_date: milestone.start_date,
                start_date_sourcing_milestone_id: milestone.id,
                start_date_sourcing_work_item_id: nil
              )
            end
          end

          context "when params[:start_date_fixed] is nil" do
            let(:params) { { start_date_is_fixed: true, start_date_fixed: nil } }

            it "sets the start_date and start_date_fixed to nil" do
              expect(builder.build).to eq(
                start_date: nil,
                start_date_fixed: nil,
                start_date_is_fixed: true
              )
            end
          end
        end
      end

      context "when params[:start_date_is_fixed] is false" do
        let(:params) { { start_date_is_fixed: false } }

        it "sets the start_date to the rolledup value" do
          expect(builder.build).to eq(
            start_date_is_fixed: false,
            start_date: milestone.start_date,
            start_date_sourcing_milestone_id: milestone.id,
            start_date_sourcing_work_item_id: nil
          )
        end
      end
    end

    context "when updating due_date" do
      context "when params[:due_date_is_fixed] is true" do
        context "when params[:due_date_fixed] is not provided" do
          let(:params) { { due_date_is_fixed: true } }

          it "does not set due_date and due_date_fixed values" do
            expect(builder.build).to eq(
              due_date_is_fixed: true
            )
          end
        end

        context "when params[:due_date_fixed] is provided" do
          let(:params) { { due_date_is_fixed: true, due_date_fixed: due_date } }

          it "sets the due_date and due_date_fixed to the given value" do
            expect(builder.build).to eq(
              due_date: due_date,
              due_date_fixed: due_date,
              due_date_is_fixed: true
            )
          end

          context "when params[:due_date_fixed] is nil and due_date_is_fixed: false" do
            let(:params) { { due_date_is_fixed: false, due_date_fixed: nil } }

            it "sets the due_date and due_date_fixed to nil and due_date_is_fixed to false" do
              expect(builder.build).to eq(
                due_date_is_fixed: false,
                due_date_fixed: nil,
                due_date: milestone.due_date,
                due_date_sourcing_milestone_id: milestone.id,
                due_date_sourcing_work_item_id: nil
              )
            end
          end

          context "when params[:due_date_fixed] is nil" do
            let(:params) { { due_date_is_fixed: true, due_date_fixed: nil } }

            it "sets the due_date and due_date_fixed to nil" do
              expect(builder.build).to eq(
                due_date: nil,
                due_date_fixed: nil,
                due_date_is_fixed: true
              )
            end
          end
        end
      end

      context "when params[:due_date_is_fixed] is false" do
        let(:params) { { due_date_is_fixed: false } }

        it "sets the due_date to the rolledup value" do
          expect(builder.build).to eq(
            due_date_is_fixed: false,
            due_date: milestone.due_date,
            due_date_sourcing_milestone_id: milestone.id,
            due_date_sourcing_work_item_id: nil
          )
        end
      end
    end

    context "when all params are empty" do
      let(:params) { {} }

      it "creates the work_item dates_source and populates it" do
        expect(builder.build).to eq({})
      end
    end
  end
end
