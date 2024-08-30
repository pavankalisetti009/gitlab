# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }
  let_it_be(:project_work_item, refind: true) { create(:work_item, project: project) }
  let_it_be(:synced_epic) { create(:epic, :with_synced_work_item, group: group) }

  let(:work_item) { project_work_item }
  let(:mutation) { graphql_mutation(:workItemUpdate, input.merge('id' => work_item.to_global_id.to_s), fields) }

  let(:mutation_response) { graphql_mutation_response(:work_item_update) }

  shared_examples 'work item is not updated' do
    it 'ignores the update' do
      work_item.reload

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
        work_item.reload
      end.not_to change(&work_item_change)
    end
  end

  context 'when updating confidentiality' do
    let(:current_user) { reporter }
    let(:input) { { 'confidential' => true } }

    let(:fields) do
      <<~FIELDS
        workItem {
          confidential
        }
        errors
      FIELDS
    end

    it 'successfully updates work item' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
        work_item.reload
      end.to change(work_item, :confidential).from(false).to(true)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['workItem']).to include(
        'confidential' => true
      )
    end

    context 'when the work item has synced epic' do
      let_it_be(:work_item) { synced_epic.work_item }

      it 'successfully updates work item' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
          work_item.reload
        end.to change(work_item, :confidential).from(false).to(true)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['workItem']).to include(
          'confidential' => true
        )
      end

      context 'when work_item_epics feature flag is disabled' do
        before do
          stub_feature_flags(work_item_epics: false)
        end

        it 'does not change confidentiality' do
          work_item.reload

          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.to not_change(work_item, :confidential)
        end
      end
    end
  end

  context 'with iteration widget input' do
    let_it_be(:cadence) { create(:iterations_cadence, group: group) }
    let_it_be(:old_iteration) { create(:iteration, iterations_cadence: cadence) }
    let_it_be(:new_iteration) { create(:iteration, iterations_cadence: cadence) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetIteration {
              iteration {
                id
              }
            }
          }
        }
        errors
      FIELDS
    end

    let(:iteration_id) { new_iteration.to_global_id.to_s }
    let(:input) { { 'iterationWidget' => { 'iterationId' => iteration_id } } }

    before do
      work_item.update!(iteration: old_iteration)
    end

    context 'when iterations feature is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(iterations: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item.iteration } }
      end
    end

    context 'when iterations feature is licensed' do
      before do
        stub_licensed_features(iterations: true)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item.iteration } }
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        shared_examples "work item's iteration is updated" do
          it "updates the work item's iteration" do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)

              work_item.reload
            end.to change(work_item, :iteration).from(old_iteration).to(new_iteration)

            expect(response).to have_gitlab_http_status(:success)
          end
        end

        context 'when setting to a new iteration' do
          it_behaves_like "work item's iteration is updated"
        end

        context 'when setting iteration to null' do
          let(:new_iteration) { nil }
          let(:iteration_id) { nil }

          it_behaves_like "work item's iteration is updated"
        end

        context 'when the work item has synced epic' do
          let_it_be(:work_item) { synced_epic.work_item }

          it_behaves_like 'work item is not updated' do
            let(:work_item_change) { -> { work_item.iteration } }
          end
        end
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item.iteration } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end
  end

  context 'with weight widget input' do
    let(:new_weight) { 2 }
    let(:input) { { 'weightWidget' => { 'weight' => new_weight } } }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetWeight {
              weight
            }
            ... on WorkItemWidgetDescription {
              description
            }
          }
        }
        errors
      FIELDS
    end

    context 'when issuable weights is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(issue_weights: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item.weight } }
      end
    end

    context 'when issuable weights is licensed' do
      before do
        stub_licensed_features(issue_weights: true)
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        it_behaves_like 'update work item weight widget'

        context 'when setting weight to null' do
          let(:input) do
            { 'weightWidget' => { 'weight' => nil } }
          end

          before do
            work_item.update!(weight: 2)
          end

          it 'updates the work item' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change(work_item, :weight).from(2).to(nil)

            expect(response).to have_gitlab_http_status(:success)
          end
        end

        context 'when using quick action' do
          let(:input) { { 'descriptionWidget' => { 'description' => "/weight #{new_weight}" } } }

          it_behaves_like 'update work item weight widget'

          context 'when setting weight to null' do
            let(:input) { { 'descriptionWidget' => { 'description' => "/clear_weight" } } }

            before do
              work_item.update!(weight: 2)
            end

            it 'updates the work item' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
                work_item.reload
              end.to change(work_item, :weight).from(2).to(nil)

              expect(response).to have_gitlab_http_status(:success)
            end
          end

          context 'when the work item type does not support the weight widget' do
            let_it_be(:work_item) { create(:work_item, :task, project: project) }

            let(:input) do
              { 'descriptionWidget' => { 'description' => "Updating weight.\n/weight 1" } }
            end

            before do
              WorkItems::Type.default_by_type(:task).widget_definitions
                .find_by_widget_type(:weight).update!(disabled: true)
            end

            it_behaves_like 'work item is not updated' do
              let(:work_item_change) { -> { work_item.weight } }
            end
          end
        end

        context 'when the work item is directly associated with a group' do
          let(:work_item) { create(:work_item, :group_level, namespace: group) }

          it_behaves_like 'update work item weight widget'
        end

        context 'when the work item type is Epic and has a synced epic' do
          let_it_be(:work_item) { synced_epic.work_item }

          it_behaves_like 'work item is not updated' do
            let(:work_item_change) { -> { work_item.weight } }
          end
        end
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item.weight } }
      end
    end
  end

  context 'with progress widget input' do
    let(:new_progress) { 50 }
    let(:new_current_value) { 30 }
    let(:new_start_value) { 10 }
    let(:new_end_value) { 50 }
    let(:input) do
      { 'progressWidget' => { 'current_value' => new_current_value, 'start_value' => new_start_value,
                              'end_value' => new_end_value } }
    end

    let_it_be_with_refind(:work_item) { create(:work_item, :objective, project: project) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetProgress {
              progress
              currentValue
              startValue
              endValue
            }
          }
        }
        errors
      FIELDS
    end

    def work_item_progress
      work_item.progress&.progress
    end

    context 'when okrs is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(okrs: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item_progress } }
      end
    end

    context 'when okrs is licensed' do
      before do
        stub_licensed_features(okrs: true)
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        it 'updates the progress widget' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.to change { work_item_progress }.from(nil).to(new_progress)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['workItem']['widgets']).to include(
            {
              'progress' => new_progress,
              'type' => 'PROGRESS',
              'currentValue' => new_current_value,
              'startValue' => new_start_value,
              'endValue' => new_end_value
            }
          )
        end

        context 'when the work item has synced epic' do
          let_it_be(:work_item) { synced_epic.work_item }

          it_behaves_like 'work item is not updated' do
            let(:work_item_change) { -> { work_item_progress } }
          end
        end
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item_progress } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end
  end

  context 'with color widget input' do
    let(:new_color) { '#346465' }
    let(:input) do
      { 'colorWidget' => { 'color' => new_color } }
    end

    let_it_be_with_refind(:work_item) { create(:work_item, :epic, namespace: group) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetColor {
              color
            }
          }
        }
        errors
      FIELDS
    end

    def work_item_color
      work_item.color&.color
    end

    context 'when epic_colors is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(epic_colors: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item_color } }
      end
    end

    context 'when epic_colors is licensed' do
      before do
        stub_licensed_features(epic_colors: true)
      end

      context 'when the user has permission to admin a work item' do
        let(:current_user) { reporter }

        shared_examples 'updates the color widget' do
          specify do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change { work_item_color }.from(nil).to(::Gitlab::Color.of(new_color))

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'color' => new_color,
                'type' => 'COLOR'
              }
            )
          end
        end

        it_behaves_like 'updates the color widget'

        context 'when the work item has synced epic' do
          let_it_be(:work_item) { synced_epic.work_item }

          it_behaves_like 'updates the color widget'

          context 'when work_item_epics feature flag is disabled' do
            before do
              stub_feature_flags(work_item_epics: false)
            end

            it_behaves_like 'work item is not updated' do
              let(:work_item_change) { -> { work_item_color } }
            end
          end
        end
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item_color } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end

    context "when epic is licensed" do
      before do
        stub_licensed_features(epics: true)
      end

      context "when updating rolledup dates widget" do
        let(:current_user) { reporter }
        let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }
        let_it_be(:milestone) { create(:milestone, group: group, start_date: 2.days.ago, due_date: 2.days.from_now) }
        let_it_be(:child_work_item) do
          create(:work_item, :issue, namespace: group, milestone: milestone).tap do |child|
            create(:parent_link, work_item: child, work_item_parent: work_item)
          end
        end

        let(:fields) do
          <<~FIELDS
            workItem {
              widgets {
                type
                ... on WorkItemWidgetRolledupDates {
                  startDate
                  startDateFixed
                  startDateIsFixed
                  startDateSourcingWorkItem {
                    id
                  }
                  startDateSourcingMilestone {
                    id
                  }
                  dueDate
                  dueDateFixed
                  dueDateIsFixed
                  dueDateSourcingWorkItem {
                    id
                  }
                  dueDateSourcingMilestone {
                    id
                  }
                }
              }
            }
            errors
          FIELDS
        end

        context "when updating from rolledup dates to fixed dates" do
          let_it_be(:start_date) { "2002-01-01" }
          let_it_be(:due_date) { "2002-12-31" }
          let_it_be(:dates_dource) do
            create(
              :work_items_dates_source,
              work_item: work_item,
              start_date: milestone.start_date.to_date,
              due_date: milestone.due_date.to_date)
          end

          let(:input) do
            {
              "rolledupDatesWidget" => {
                "startDateIsFixed" => true,
                "startDateFixed" => start_date,
                "dueDateIsFixed" => true,
                "dueDateFixed" => due_date
              }
            }
          end

          shared_examples "updates the work item's start and due date" do
            specify do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(response).to have_gitlab_http_status(:success)
              expect(mutation_response['workItem']['widgets']).to include(
                "type" => "ROLLEDUP_DATES",
                "dueDate" => due_date,
                "dueDateFixed" => due_date,
                "dueDateIsFixed" => true,
                "dueDateSourcingMilestone" => nil,
                "dueDateSourcingWorkItem" => nil,
                "startDate" => start_date,
                "startDateFixed" => start_date,
                "startDateIsFixed" => true,
                "startDateSourcingMilestone" => nil,
                "startDateSourcingWorkItem" => nil
              )
            end
          end

          it_behaves_like "updates the work item's start and due date"

          context 'when the work item has synced epic' do
            let_it_be(:work_item) { synced_epic.work_item }

            it_behaves_like "updates the work item's start and due date"

            context 'when work_item_epics feature flag is disabled' do
              before do
                stub_feature_flags(work_item_epics: false)
              end

              it_behaves_like 'work item is not updated' do
                let(:work_item_change) { -> { work_item.dates_source&.start_date } }
              end
            end
          end
        end

        context "when the work_items_rolledup_dates feature flag is disabled" do
          before do
            stub_feature_flags(work_items_rolledup_dates: false)
          end

          let_it_be(:start_date) { "2002-01-01" }
          let_it_be(:due_date) { "2002-12-31" }
          let_it_be(:dates_dource) do
            create(
              :work_items_dates_source,
              work_item: work_item,
              due_date_sourcing_milestone: milestone,
              due_date: milestone.due_date.to_date,
              start_date: milestone.start_date.to_date,
              start_date_sourcing_milestone: milestone)
          end

          let(:input) do
            {
              "rolledupDatesWidget" => {
                "startDateFixed" => start_date,
                "dueDateFixed" => due_date
              }
            }
          end

          it "does not update the work item's start and due date" do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['workItem']['widgets']).to include(
              "type" => "ROLLEDUP_DATES",
              "dueDate" => milestone.due_date.to_s,
              "dueDateFixed" => nil,
              "dueDateIsFixed" => false,
              "dueDateSourcingMilestone" => { "id" => milestone.to_gid.to_s },
              "dueDateSourcingWorkItem" => nil,
              "startDate" => milestone.start_date.to_s,
              "startDateFixed" => nil,
              "startDateIsFixed" => false,
              "startDateSourcingMilestone" => { "id" => milestone.to_gid.to_s },
              "startDateSourcingWorkItem" => nil)
          end
        end

        context "when updating from fixed dates to rolledup dates" do
          let_it_be(:due_date_fixed) { 1.day.from_now.to_date }
          let_it_be(:start_date_fixed) { 1.day.ago.to_date }
          let_it_be(:dates_dource) do
            create(
              :work_items_dates_source,
              work_item: work_item,
              start_date_fixed: start_date_fixed,
              start_date_is_fixed: true,
              due_date_fixed: due_date_fixed,
              due_date_is_fixed: true)
          end

          let(:input) do
            {
              "rolledupDatesWidget" => {
                "startDateIsFixed" => false,
                "dueDateIsFixed" => false
              }
            }
          end

          it "updates the work item's start and due date" do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)

            expect(mutation_response['workItem']['widgets']).to include(
              "type" => "ROLLEDUP_DATES",
              "dueDate" => milestone.due_date.to_s,
              "dueDateFixed" => due_date_fixed.to_s,
              "dueDateIsFixed" => false,
              "dueDateSourcingMilestone" => { "id" => milestone.to_gid.to_s },
              "dueDateSourcingWorkItem" => nil,
              "startDate" => milestone.start_date.to_s,
              "startDateFixed" => start_date_fixed.to_s,
              "startDateIsFixed" => false,
              "startDateSourcingMilestone" => { "id" => milestone.to_gid.to_s },
              "startDateSourcingWorkItem" => nil)
          end
        end
      end
    end
  end

  context 'with status widget input' do
    let(:new_status) { 'FAILED' }
    let(:input) { { 'statusWidget' => { 'status' => new_status } } }

    let_it_be_with_refind(:work_item) { create(:work_item, :satisfied_status, project: project) }

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetStatus {
              status
            }
          }
        }
        errors
      FIELDS
    end

    def work_item_status
      state = work_item.requirement&.last_test_report_state
      ::WorkItems::Widgets::Status::STATUS_MAP[state]
    end

    context 'when requirements is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(requirements: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item_status } }
      end
    end

    context 'when requirements is licensed' do
      before do
        stub_licensed_features(requirements: true)
      end

      context 'when user has permissions to admin a work item' do
        let(:current_user) { reporter }

        it_behaves_like 'update work item status widget'

        context 'when the work item has synced epic' do
          let_it_be(:work_item) { synced_epic.work_item }

          it_behaves_like 'work item is not updated' do
            let(:work_item_change) { -> { work_item_status } }
          end
        end

        context 'when setting status to an invalid value' do
          # while a requirement can have a status 'unverified'
          # it can't be directly set that way

          let(:input) do
            { 'statusWidget' => { 'status' => 'UNVERIFIED' } }
          end

          it "does not update the work item's status" do
            # due to 'passed' internally and 'satisfied' externally, map it here
            expect(work_item_status).to eq("satisfied")

            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.not_to change { work_item_status }

            expect(work_item_status).to eq("satisfied")
          end
        end
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item_status } }
      end

      context 'when the user does not have permission to update the work item' do
        let(:current_user) { guest }

        it_behaves_like 'work item is not updated' do
          let(:work_item_change) { -> { work_item_status } }
        end

        context 'when a base attribute is present' do
          before do
            input.merge!('title' => 'new title')
          end

          it_behaves_like 'a mutation that returns top-level errors', errors: [
            'The resource that you are attempting to access does not exist or you don\'t have permission to ' \
            'perform this action'
          ]
        end
      end
    end
  end

  context 'with health status widget input' do
    let(:new_status) { 'onTrack' }
    let(:input) { { 'healthStatusWidget' => { 'healthStatus' => new_status } } }

    let_it_be_with_refind(:work_item) do
      create(:work_item, health_status: :needs_attention, project: project)
    end

    let(:fields) do
      <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetHealthStatus {
              healthStatus
            }
            ... on WorkItemWidgetDescription {
              description
            }
          }
        }
        errors
      FIELDS
    end

    context 'when issuable_health_status is unlicensed' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(issuable_health_status: false)
      end

      it_behaves_like 'work item is not updated' do
        let(:work_item_change) { -> { work_item.health_status } }
      end
    end

    context 'when issuable_health_status is licensed' do
      before do
        stub_licensed_features(issuable_health_status: true)
      end

      it_behaves_like 'work item is not updated' do
        let(:current_user) { guest }
        let(:work_item_change) { -> { work_item.health_status } }
      end

      context 'when user has permissions to update the work item' do
        let(:current_user) { reporter }

        it 'updates work item health status' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.to change { work_item.health_status }.from('needs_attention').to('on_track')

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['workItem']['widgets']).to include(
            {
              'healthStatus' => 'onTrack',
              'type' => 'HEALTH_STATUS'
            }
          )
        end

        context 'when using quick action' do
          let(:input) { { 'descriptionWidget' => { 'description' => "/health_status on_track" } } }

          it 'updates work item health status' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change { work_item.health_status }.from('needs_attention').to('on_track')

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'healthStatus' => 'onTrack',
                'type' => 'HEALTH_STATUS'
              }
            )
          end

          context 'when clearing health status' do
            let(:input) { { 'descriptionWidget' => { 'description' => "/clear_health_status" } } }

            it 'updates the work item' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
                work_item.reload
              end.to change { work_item.health_status }.from('needs_attention').to(nil)

              expect(response).to have_gitlab_http_status(:success)
            end
          end

          context 'when the work item type does not support the health status widget' do
            let_it_be(:work_item) { create(:work_item, project: project) }

            let(:input) do
              { 'descriptionWidget' => { 'description' => "Updating health status.\n/health_status on_track" } }
            end

            before do
              WorkItems::Type.default_by_type(:issue).widget_definitions
                .find_by_widget_type(:health_status).update!(disabled: true)
            end

            it_behaves_like 'work item is not updated' do
              let(:work_item_change) { -> { work_item.health_status } }
            end
          end
        end

        context 'when the work item has synced epic' do
          let_it_be(:work_item) { synced_epic.work_item }

          it 'updates work item health status' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change { work_item.health_status }.from(nil).to('on_track')

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['workItem']['widgets']).to include(
              {
                'healthStatus' => 'onTrack',
                'type' => 'HEALTH_STATUS'
              }
            )
          end

          context 'when work_item_epics feature flag is disabled' do
            before do
              stub_feature_flags(work_item_epics: false)
            end

            it_behaves_like 'work item is not updated' do
              let(:work_item_change) { -> { work_item.health_status } }
            end
          end
        end
      end
    end
  end

  context 'when changing work item type' do
    let(:fields) do
      <<~FIELDS
        workItem {
          workItemType {
            name
          }
        }
        errors
      FIELDS
    end

    context 'when using quick action' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(okrs: true, epics: true, subepics: true)
      end

      context 'for epic work item type' do
        let(:input) { { 'descriptionWidget' => { 'description' => "/type objective" } } }
        let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
        let(:work_item) { epic.work_item }

        it 'does not update work item type' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
            work_item.reload
          end.not_to change { work_item.work_item_type.base_type }

          expect(response).to have_gitlab_http_status(:success)
        end
      end
    end
  end

  context 'with hierarchy widget input' do
    let(:widgets_response) { mutation_response['workItem']['widgets'] }
    let(:fields) do
      <<~FIELDS
        workItem {
          description
          widgets {
            type
            ... on WorkItemWidgetHierarchy {
              parent {
                id
              }
              children {
                edges {
                  node {
                    id
                  }
                }
              }
            }
          }
        }
        errors
      FIELDS
    end

    before do
      stub_licensed_features(epics: true, subepics: true)
    end

    context 'when updating parent' do
      let_it_be(:work_item_epic, reload: true) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:work_item_issue, reload: true) { create(:work_item, :issue, project: project) }

      let_it_be(:new_parent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

      let(:input) { { 'hierarchyWidget' => { 'parentId' => new_parent.to_global_id.to_s } } }

      it 'updates work item parent and synced epic parent when moving child is epic' do
        expect do
          post_graphql_mutation(mutation_for(work_item_epic), current_user: reporter)
        end.to change { work_item_epic.reload.work_item_parent }.from(nil).to(new_parent)
            .and change { work_item_epic.synced_epic.reload.parent }.from(nil).to(new_parent.synced_epic)

        expect(response).to have_gitlab_http_status(:success)
        expect(widgets_response).to include({ 'type' => 'HIERARCHY', 'children' => { 'edges' => [] },
                                              'parent' => { 'id' => new_parent.to_global_id.to_s } })
      end

      it 'updates work item parent when moving child is issue' do
        expect do
          post_graphql_mutation(mutation_for(work_item_issue), current_user: reporter)
        end.to change { work_item_issue.reload.work_item_parent }.from(nil).to(new_parent)

        expect(response).to have_gitlab_http_status(:success)
        expect(widgets_response).to include({ 'type' => 'HIERARCHY', 'children' => { 'edges' => [] },
                                              'parent' => { 'id' => new_parent.to_global_id.to_s } })
      end

      context 'when a parent is already present' do
        let_it_be(:existing_parent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

        let_it_be(:work_item_epic_link) do
          create(:parent_link, work_item: work_item_epic, work_item_parent: existing_parent, relative_position: 10)
        end

        let_it_be(:work_item_issue_link) do
          create(:parent_link, work_item: work_item_issue, work_item_parent: existing_parent, relative_position: 20)
        end

        before do
          work_item_epic.synced_epic.update!(parent: existing_parent.synced_epic)
          create(:epic_issue, epic: existing_parent.synced_epic, issue: work_item_issue)
        end

        it 'syncs with legacy epic if child is epic' do
          expect do
            post_graphql_mutation(mutation_for(work_item_epic), current_user: reporter)
          end.to change { work_item_epic.reload.work_item_parent }.from(existing_parent).to(new_parent)
             .and change { work_item_epic.synced_epic.reload.parent }.from(existing_parent.synced_epic)
                                                                    .to(new_parent.synced_epic)

          expect(response).to have_gitlab_http_status(:success)
          expect(widgets_response).to include({ 'type' => 'HIERARCHY', 'children' => { 'edges' => [] },
                                                'parent' => { 'id' => new_parent.to_global_id.to_s } })
        end

        it 'syncs with epic_issue if child is issue' do
          expect do
            post_graphql_mutation(mutation_for(work_item_issue), current_user: reporter)
          end.to change { work_item_issue.reload.work_item_parent }.from(existing_parent).to(new_parent)
             .and change { work_item_issue.epic_issue.reload.epic }.from(existing_parent.synced_epic)
                                                            .to(new_parent.synced_epic)

          expect(response).to have_gitlab_http_status(:success)
          expect(widgets_response).to include({ 'type' => 'HIERARCHY', 'children' => { 'edges' => [] },
                                                'parent' => { 'id' => new_parent.to_global_id.to_s } })
        end

        context 'and new parent has existing children' do
          let_it_be(:child_in_new_parent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

          let(:input) do
            { 'hierarchyWidget' => {
              'parentId' => new_parent.to_global_id.to_s,
              adjacentWorkItemId: child_in_new_parent.to_global_id.to_s,
              relativePosition: "AFTER"
            } }
          end

          before do
            create(:parent_link, work_item: child_in_new_parent, work_item_parent: new_parent, relative_position: 10)
            child_in_new_parent.synced_epic.update!(parent: new_parent.synced_epic)
          end

          context 'when moving child is an epic' do
            it 'syncs with legacy epic' do
              expect do
                post_graphql_mutation(mutation_for(work_item_epic), current_user: reporter)
              end.to change { work_item_epic.reload.work_item_parent }.from(existing_parent).to(new_parent)
                 .and change { work_item_epic.synced_epic.reload.parent }.from(existing_parent.synced_epic)
                                                                         .to(new_parent.synced_epic)

              expect(response).to have_gitlab_http_status(:success)
              expect(new_parent.work_item_children_by_relative_position.pluck(:id))
                .to match_array([child_in_new_parent.id, work_item_epic.id])
            end

            it 'does not move child if syncing parent fails' do
              allow_next_found_instance_of(::Epic) do |instance|
                allow(instance).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
              end

              expect do
                post_graphql_mutation(mutation_for(work_item_epic), current_user: reporter)
              end.to not_change { work_item_epic.reload.work_item_parent }
                 .and not_change { work_item_epic.synced_epic.reload.parent }
                 .and not_change { work_item_epic_link.reload }

              expect(mutation_response["errors"]).to include("Couldn't re-order due to an internal error.")
            end
          end

          context 'when moving child is an issue' do
            it 'syncs with epic_issue' do
              expect do
                post_graphql_mutation(mutation_for(work_item_issue), current_user: reporter)
              end.to change { work_item_issue.reload.work_item_parent }.from(existing_parent).to(new_parent)
                 .and change { work_item_issue.epic_issue.reload.epic }.from(existing_parent.synced_epic)
                                                                       .to(new_parent.synced_epic)

              expect(response).to have_gitlab_http_status(:success)
              expect(new_parent.work_item_children_by_relative_position.pluck(:id))
                .to match_array([child_in_new_parent.id, work_item_issue.id])
            end

            it 'does not move child if syncing parent fails' do
              allow_next_found_instance_of(::EpicIssue) do |instance|
                allow(instance).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
              end

              expect do
                post_graphql_mutation(mutation_for(work_item_issue), current_user: reporter)
              end.to not_change { work_item_issue.reload.work_item_parent }
                 .and not_change { work_item_issue.epic_issue.reload.epic }
                 .and not_change { work_item_issue_link.reload }

              expect(mutation_response["errors"]).to include("Couldn't re-order due to an internal error.")
            end
          end

          context 'when changing parent fails' do
            before do
              allow_next_found_instance_of(::WorkItems::ParentLink) do |instance|
                allow(instance).to receive(:save).and_return(false)

                errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:work_item, 'error message') }
                allow(instance).to receive(:errors).and_return(errors)
              end
            end

            it 'does not sync change to legacy epic parent when moving an epic' do
              expect do
                post_graphql_mutation(mutation_for(work_item_epic), current_user: reporter)
              end.to not_change { work_item_epic.reload.work_item_parent }
                 .and not_change { work_item_epic.synced_epic.reload.parent }
                 .and not_change { work_item_epic_link.reload }

              expect(mutation_response["errors"])
                .to include("#{work_item_epic.to_reference} cannot be added: error message")
            end

            it 'does not sync change to epic_issue when moving an issue' do
              expect do
                post_graphql_mutation(mutation_for(work_item_issue), current_user: reporter)
              end.to not_change { work_item_issue.reload.work_item_parent }
                 .and not_change { work_item_issue.epic_issue.reload.epic }
                 .and not_change { work_item_issue_link.reload }

              expect(mutation_response["errors"])
                .to include("#{work_item_issue.to_reference} cannot be added: error message")
            end
          end
        end
      end
    end
  end

  def mutation_for(item)
    graphql_mutation(:workItemUpdate, input.merge('id' => item.to_global_id.to_s), fields)
  end
end
