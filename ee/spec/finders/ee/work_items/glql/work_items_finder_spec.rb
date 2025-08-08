# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Glql::WorkItemsFinder, :elastic_delete_by_query, :sidekiq_inline, feature_category: :markdown do
  let_it_be(:group)           { create(:group) }
  let_it_be(:project)         { create(:project, group: group) }
  let_it_be(:current_user)    { create(:user) }
  let_it_be(:work_item1) do
    create(:work_item, project: project)
  end

  let_it_be(:work_item2) do
    create(:work_item, project: project)
  end

  let(:params)         { {} }
  let(:finder)         { described_class.new(current_user, context, resource_parent, params) }
  let(:context)        { instance_double(GraphQL::Query::Context) }
  let(:request_params) { { 'operationName' => 'GLQL' } }
  let(:url_query)      { 'useES=true' }
  let(:url)            { 'http://localhost' }
  let(:referer)        { "#{url}?#{url_query}" }

  let(:dummy_request) do
    instance_double(ActionDispatch::Request,
      params: request_params,
      referer: referer
    )
  end

  before do
    allow(context).to receive(:[]).with(:request).and_return(dummy_request)

    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  subject(:execute) { finder.execute.to_a }

  describe '#use_elasticsearch_finder?' do
    let(:resource_parent) { group }

    context 'when falling back to legacy finder' do
      context 'when the request is not a GLQL request' do
        let(:request_params) { { 'operationName' => 'Not GLQL' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when url param is not enabled' do
        let(:url_query) { 'useES=false' }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:elasticsearch_search?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled per group' do
        before do
          allow(resource_parent).to receive(:use_elasticsearch?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when not supported search param is used' do
        let(:params) { { not_suported: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `not` operator is used with supported filter' do
        let(:params) { { not: { author_username: current_user.username } } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when `not` operator is used with not supported filter' do
        let(:params) { { not: { not_suported: 'something' } } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `not` operator is not a hash' do
        let(:params) { { not: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `or` operator is used with supported filter' do
        let(:params) { { or: { assignee_usernames: [current_user.username] } } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when `or` operator is used with not supported filter' do
        let(:params) { { or: { not_suported: 'something' } } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `or` operator is not a hash' do
        let(:params) { { or: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end
    end

    context 'when using ES finder' do
      context 'when all the conditions are met' do
        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when url param is missing (since we do not want to force using this param)' do
        let(:url_query) { '' }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end
    end
  end

  describe '#parent_param=' do
    context 'when resource_parent is a Group' do
      let(:resource_parent) { group }

      it 'sets the group_id and leaves project_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:project_id]).to be_nil
        expect(finder.params[:group_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is a Project' do
      let_it_be(:resource_parent) { project }

      it 'sets the project_id and leaves group_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:group_id]).to be_nil
        expect(finder.params[:project_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is not allowed' do
      let_it_be(:resource_parent) { create(:merge_request) }

      it 'raises an error for unexpected parent type' do
        expect { finder.parent_param }.to raise_error(RuntimeError, 'Unexpected parent: MergeRequest')
      end
    end
  end

  describe '#execute' do
    context 'when resource_parent is a Group' do
      let(:resource_parent) { group }

      before_all do
        group.add_owner(current_user)
      end

      context 'when searching for author_username' do
        let(:another_user) { create(:user) }
        let(:work_item1_with_author) { create(:work_item, project: project, author: current_user) }
        let(:work_item2_with_author) { create(:work_item, project: project, author: another_user) }

        before do
          Elastic::ProcessBookkeepingService.track!(work_item1_with_author, work_item2_with_author)

          ensure_elasticsearch_index!
        end

        context 'when author_username param provided' do
          let(:params) do
            { author_username: [current_user.username] }
          end

          it 'returns work items with specified author username' do
            expect(execute).to contain_exactly(work_item1_with_author)
          end
        end

        context 'when not_author_username param provided' do
          let(:params) do
            {
              not: {
                author_username: [current_user.username]
              }
            }
          end

          it 'returns work items without specified author username' do
            expect(execute).to contain_exactly(work_item2_with_author)
          end
        end
      end

      context 'when searching for milestone' do
        let(:milestone1) { create(:milestone, group: group) }
        let(:milestone2) { create(:milestone, group: group) }
        let(:work_item1_with_milestone) { create(:work_item, project: project, milestone: milestone1) }
        let(:work_item2_with_milestone) { create(:work_item, project: project, milestone: milestone2) }
        let(:work_item3_without_milestone) { create(:work_item, project: project) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item1_with_milestone,
            work_item2_with_milestone,
            work_item3_without_milestone
          )

          ensure_elasticsearch_index!
        end

        context 'when milestone_title param provided' do
          let(:params) do
            { milestone_title: [milestone1.title] }
          end

          it 'returns work items with specified title' do
            expect(execute).to contain_exactly(work_item1_with_milestone)
          end
        end

        context 'when not_milestone_title param provided' do
          let(:params) do
            {
              not: {
                milestone_title: [milestone2.title]
              }
            }
          end

          it 'returns work items without specified title' do
            expect(execute).to contain_exactly(work_item1_with_milestone, work_item3_without_milestone)
          end
        end

        context 'when milestone_title param with multiple titles provided' do
          let(:params) do
            { milestone_title: [milestone1.title, milestone2.title] }
          end

          it 'returns work items with specified titles' do
            expect(execute).to contain_exactly(work_item1_with_milestone, work_item2_with_milestone)
          end
        end

        context 'when milestone_wildcard_id with NONE provided' do
          let(:params) do
            { milestone_wildcard_id: 'NONE' }
          end

          it 'returns work items without milestone' do
            expect(execute).to contain_exactly(work_item3_without_milestone)
          end
        end

        context 'when milestone_wildcard_id with ANY provided' do
          let(:params) do
            { milestone_wildcard_id: 'ANY' }
          end

          it 'returns all work items with any milestone' do
            expect(execute).to contain_exactly(work_item1_with_milestone, work_item2_with_milestone)
          end
        end
      end

      context 'with milestone state wildcard filters' do
        let(:upcoming_milestone) do
          create(:milestone, group: group, start_date: 1.day.from_now, due_date: 1.week.from_now)
        end

        let(:started_milestone) do
          create(:milestone, group: group, start_date: 1.day.ago, due_date: 1.week.from_now)
        end

        let(:work_item_with_upcoming_milestone) do
          create(:work_item, project: project, milestone: upcoming_milestone)
        end

        let(:work_item_with_started_milestone) do
          create(:work_item, project: project, milestone: started_milestone)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_with_upcoming_milestone,
            work_item_with_started_milestone
          )
          ensure_elasticsearch_index!
        end

        context 'when milestone_wildcard_id with UPCOMING provided' do
          let(:params) do
            { milestone_wildcard_id: 'UPCOMING' }
          end

          it 'returns work items with upcoming active milestones' do
            expect(execute).to contain_exactly(work_item_with_upcoming_milestone)
          end
        end

        context 'when milestone_wildcard_id with STARTED provided' do
          let(:params) do
            { milestone_wildcard_id: 'STARTED' }
          end

          it 'returns work items with started active milestones' do
            expect(execute).to contain_exactly(work_item_with_started_milestone)
          end
        end

        context 'when NOT milestone_wildcard_id with UPCOMING provided' do
          let(:params) do
            {
              not: {
                milestone_wildcard_id: 'UPCOMING'
              }
            }
          end

          it 'returns work items without upcoming milestones' do
            expect(execute).to contain_exactly(work_item_with_started_milestone)
          end
        end

        context 'when NOT milestone_wildcard_id with STARTED provided' do
          let(:params) do
            {
              not: {
                milestone_wildcard_id: 'STARTED'
              }
            }
          end

          it 'returns work items without started milestones' do
            expect(execute).to contain_exactly(work_item_with_upcoming_milestone)
          end
        end
      end

      context 'when searching for weight' do
        let(:work_item_with_weight_5) { create(:work_item, project: project, weight: 5) }
        let(:work_item_with_weight_10) { create(:work_item, project: project, weight: 10) }
        let(:work_item_without_weight) { create(:work_item, project: project, weight: nil) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_with_weight_5,
            work_item_with_weight_10,
            work_item_without_weight
          )

          ensure_elasticsearch_index!
        end

        context 'when weight param provided' do
          let(:params) do
            { weight: '5' }
          end

          it 'returns work items with specified weight' do
            expect(execute).to contain_exactly(work_item_with_weight_5)
          end
        end

        context 'when not_weight param provided' do
          let(:params) do
            {
              not: {
                weight: '10'
              }
            }
          end

          it 'returns work items without specified weight' do
            expect(execute).to contain_exactly(work_item_with_weight_5, work_item_without_weight)
          end
        end

        context 'when weight_wildcard_id with ANY provided' do
          let(:params) do
            { weight_wildcard_id: 'ANY' }
          end

          it 'returns all work items with any weight' do
            expect(execute).to contain_exactly(work_item_with_weight_5, work_item_with_weight_10)
          end
        end

        context 'when weight_wildcard_id with NONE provided' do
          let(:params) do
            { weight_wildcard_id: 'NONE' }
          end

          it 'returns work items without weight' do
            expect(execute).to contain_exactly(work_item_without_weight)
          end
        end
      end

      context 'when searching for assignee' do
        let(:user1) { create(:user) }
        let(:user2) { create(:user) }
        let(:user3) { create(:user) }
        let(:work_item_assigned_to_user1) { create(:work_item, project: project, assignees: [user1]) }
        let(:work_item_assigned_to_user2) { create(:work_item, project: project, assignees: [user2]) }
        let(:work_item_assigned_to_user3) { create(:work_item, project: project, assignees: [user3]) }
        let(:work_item_assigned_to_multiple) { create(:work_item, project: project, assignees: [user1, user2]) }
        let(:work_item_without_assignee) { create(:work_item, project: project, assignees: []) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_assigned_to_user1,
            work_item_assigned_to_user2,
            work_item_assigned_to_user3,
            work_item_assigned_to_multiple,
            work_item_without_assignee
          )

          ensure_elasticsearch_index!
        end

        context 'when assignee username provided' do
          let(:params) do
            { assignee_usernames: [user1.username] }
          end

          it 'returns work items assigned to specified user' do
            expect(execute).to contain_exactly(work_item_assigned_to_user1, work_item_assigned_to_multiple)
          end
        end

        context 'when multiple assignee usernames provided' do
          let(:params) do
            { assignee_usernames: [user1.username, user2.username] }
          end

          it 'returns work items assigned to all specified users' do
            expect(execute).to contain_exactly(work_item_assigned_to_multiple)
          end
        end

        context 'when not_assignee_usernames param provided' do
          let(:params) do
            {
              not: {
                assignee_usernames: [user2.username]
              }
            }
          end

          it 'returns work items not assigned to specified user' do
            expect(execute).to contain_exactly(
              work_item_assigned_to_user1,
              work_item_assigned_to_user3,
              work_item_without_assignee
            )
          end
        end

        context 'when or assignee param provided' do
          let(:params) do
            {
              or: {
                assignee_usernames: [user1.username, user3.username]
              }
            }
          end

          it 'returns work items assigned to any of the specified users' do
            expect(execute).to contain_exactly(
              work_item_assigned_to_user1,
              work_item_assigned_to_user3,
              work_item_assigned_to_multiple
            )
          end
        end

        context 'when assignee_wildcard_id with ANY provided' do
          let(:params) do
            { assignee_wildcard_id: 'ANY' }
          end

          it 'returns all work items with any assignee' do
            expect(execute).to contain_exactly(
              work_item_assigned_to_user1,
              work_item_assigned_to_user2,
              work_item_assigned_to_user3,
              work_item_assigned_to_multiple
            )
          end
        end

        context 'when assignee_wildcard_id with NONE provided' do
          let(:params) do
            { assignee_wildcard_id: 'NONE' }
          end

          it 'returns work items without assignee' do
            expect(execute).to contain_exactly(work_item_without_assignee)
          end
        end
      end

      context 'when searching for label_names' do
        let(:bug_label) { create(:label, project: project, title: 'bug') }
        let(:feature_label) { create(:label, project: project, title: 'feature') }
        let(:scoped_group_label) { create(:label, project: project, title: 'group::knowledge') }
        let(:different_scoped_label) { create(:label, project: project, title: 'priority::high') }

        let(:work_item_with_bug_label) { create(:work_item, project: project, labels: [bug_label]) }
        let(:work_item_with_feature_label) { create(:work_item, project: project, labels: [feature_label]) }
        let(:work_item_with_scoped_group_label) { create(:work_item, project: project, labels: [scoped_group_label]) }
        let(:work_item_with_different_scoped_label) do
          create(:work_item, project: project, labels: [different_scoped_label])
        end

        let(:work_item_with_multiple_labels) do
          create(:work_item, project: project, labels: [bug_label, scoped_group_label])
        end

        let(:work_item_without_labels) { create(:work_item, project: project, labels: []) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_with_bug_label,
            work_item_with_feature_label,
            work_item_with_scoped_group_label,
            work_item_with_different_scoped_label,
            work_item_with_multiple_labels,
            work_item_without_labels
          )

          ensure_elasticsearch_index!
        end

        context 'when label_names param provided' do
          let(:params) do
            { label_name: ['bug'] }
          end

          it 'returns work items with specified label' do
            expect(execute).to contain_exactly(work_item_with_bug_label, work_item_with_multiple_labels)
          end
        end

        context 'when label_names param with wildcard provided' do
          let(:params) do
            { label_name: ['group::*'] }
          end

          it 'returns work items with scoped labels matching wildcard pattern' do
            expect(execute).to contain_exactly(work_item_with_scoped_group_label, work_item_with_multiple_labels)
          end
        end

        context 'when not_label_names param provided' do
          let(:params) do
            {
              not: {
                label_name: ['bug']
              }
            }
          end

          it 'returns work items without specified label' do
            expect(execute).to contain_exactly(
              work_item_with_feature_label,
              work_item_with_scoped_group_label,
              work_item_with_different_scoped_label,
              work_item_without_labels
            )
          end
        end

        context 'when or_label_names param provided' do
          let(:params) do
            {
              or: {
                label_names: %w[bug feature]
              }
            }
          end

          it 'returns work items with any of the specified labels' do
            expect(execute).to contain_exactly(
              work_item_with_bug_label,
              work_item_with_feature_label,
              work_item_with_multiple_labels
            )
          end
        end

        context 'when label_name with ANY provided' do
          let(:params) do
            { label_name: ['ANY'] }
          end

          it 'returns all work items with any label' do
            expect(execute).to contain_exactly(
              work_item_with_bug_label,
              work_item_with_feature_label,
              work_item_with_scoped_group_label,
              work_item_with_different_scoped_label,
              work_item_with_multiple_labels
            )
          end
        end

        context 'when label_name with NONE provided' do
          let(:params) do
            { label_name: ['NONE'] }
          end

          it 'returns work items without any labels' do
            expect(execute).to contain_exactly(work_item_without_labels)
          end
        end
      end

      context 'when searching for health_status' do
        let(:work_item_on_track) { create(:work_item, project: project, health_status: 'on_track') }
        let(:work_item_needs_attention) { create(:work_item, project: project, health_status: 'needs_attention') }
        let(:work_item_at_risk) { create(:work_item, project: project, health_status: 'at_risk') }
        let(:work_item_without_health_status) { create(:work_item, project: project, health_status: nil) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_on_track,
            work_item_needs_attention,
            work_item_at_risk,
            work_item_without_health_status
          )

          ensure_elasticsearch_index!
        end

        context 'when health_status param provided' do
          let(:params) do
            { health_status_filter: 'on_track' }
          end

          it 'returns work items with specified health status' do
            expect(execute).to contain_exactly(work_item_on_track)
          end
        end

        context 'when multiple health_status values provided' do
          let(:params) do
            { health_status_filter: %w[on_track at_risk] }
          end

          it 'returns work items with any of the specified health statuses' do
            expect(execute).to contain_exactly(work_item_on_track, work_item_at_risk)
          end
        end

        context 'when not_health_status param provided' do
          let(:params) do
            {
              not: {
                health_status_filter: ['needs_attention']
              }
            }
          end

          it 'returns work items without specified health status' do
            expect(execute).to contain_exactly(work_item_on_track, work_item_at_risk, work_item_without_health_status)
          end
        end

        context 'when health_status_filter with ANY provided' do
          let(:params) do
            { health_status_filter: 'ANY' }
          end

          it 'returns all work items with any health status' do
            expect(execute).to contain_exactly(work_item_on_track, work_item_needs_attention, work_item_at_risk)
          end
        end

        context 'when health_status_filter with NONE provided' do
          let(:params) do
            { health_status_filter: 'NONE' }
          end

          it 'returns work items without health status' do
            expect(execute).to contain_exactly(work_item_without_health_status)
          end
        end
      end

      context 'when searching for state' do
        let(:opened_work_item) { create(:work_item, project: project, state: 'opened') }
        let(:closed_work_item) { create(:work_item, project: project, state: 'closed') }

        before do
          Elastic::ProcessBookkeepingService.track!(opened_work_item, closed_work_item)

          ensure_elasticsearch_index!
        end

        context 'when state param is opened' do
          let(:params) do
            { state: 'opened' }
          end

          it 'returns only opened work items' do
            expect(execute).to contain_exactly(opened_work_item)
          end
        end

        context 'when state param is closed' do
          let(:params) do
            { state: 'closed' }
          end

          it 'returns only closed work items' do
            expect(execute).to contain_exactly(closed_work_item)
          end
        end

        context 'when state param is all' do
          let(:params) do
            { state: 'all' }
          end

          it 'returns all work items regardless of state' do
            expect(execute).to contain_exactly(opened_work_item, closed_work_item)
          end
        end

        context 'when state param is not provided' do
          it 'returns all work items regardless of state' do
            expect(execute).to contain_exactly(opened_work_item, closed_work_item)
          end
        end
      end

      context 'when searching for issue_types' do
        let(:issue) { create(:work_item, :issue, project: project) }
        let(:task) { create(:work_item, :task, project: project) }
        let(:requirement) { create(:work_item, :requirement, project: project) }

        before do
          Elastic::ProcessBookkeepingService.track!(issue, task, requirement)

          ensure_elasticsearch_index!
        end

        context 'when issue_types param with single type provided' do
          let(:params) do
            { issue_types: ['issue'] }
          end

          it 'returns only work items of specified type' do
            expect(execute).to contain_exactly(issue)
          end
        end

        context 'when issue_types param with multiple types provided' do
          let(:params) do
            { issue_types: %w[issue task] }
          end

          it 'returns work items of any specified types' do
            expect(execute).to contain_exactly(issue, task)
          end
        end

        context 'when issue_types param with requirement type provided' do
          let(:params) do
            { issue_types: ['requirement'] }
          end

          it 'returns only requirement work items' do
            expect(execute).to contain_exactly(requirement)
          end
        end

        context 'when issue_types param is not provided' do
          it 'returns all work items regardless of type' do
            expect(execute).to contain_exactly(issue, task, requirement)
          end
        end

        context 'when issue_types param with all supported types provided' do
          let(:params) do
            { issue_types: %w[issue task requirement] }
          end

          it 'returns work items of all specified types' do
            expect(execute).to contain_exactly(issue, task, requirement)
          end
        end
      end

      context 'when searching for confidential' do
        let(:confidential_work_item) { create(:work_item, project: project, confidential: true) }
        let(:non_confidential_work_item) { create(:work_item, project: project, confidential: false) }

        before_all do
          project.add_owner(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(
            confidential_work_item,
            non_confidential_work_item
          )

          ensure_elasticsearch_index!
        end

        context 'when confidential param is true' do
          let(:params) do
            { confidential: true }
          end

          it 'returns only confidential work items' do
            expect(execute).to contain_exactly(confidential_work_item)
          end
        end

        context 'when confidential param is false' do
          let(:params) do
            { confidential: false }
          end

          it 'returns only non-confidential work items' do
            expect(execute).to contain_exactly(non_confidential_work_item)
          end
        end

        context 'when confidential param is not provided' do
          it 'returns all work items regardless of confidential status' do
            expect(execute).to contain_exactly(confidential_work_item, non_confidential_work_item)
          end
        end

        context 'when user lacks permissions for confidential items' do
          let_it_be(:guest_user) { create(:user) }
          let(:params) { { confidential: true } }
          let(:finder) { described_class.new(guest_user, context, resource_parent, params) }

          before_all do
            project.add_guest(guest_user)
          end

          it 'returns no confidential work items due to insufficient permissions' do
            expect(execute).to be_empty
          end
        end
      end
    end

    context 'when resource_parent is a Project' do
      let_it_be(:other_project) { create(:project, namespace: group) }
      let(:resource_parent) { project }

      let_it_be(:work_item_in_project) { create(:work_item, project: project) }
      let_it_be(:work_item_in_other_project) { create(:work_item, project: other_project) }

      before_all do
        project.add_reporter(current_user)
        other_project.add_reporter(current_user)
      end

      before do
        Elastic::ProcessBookkeepingService.track!(
          work_item_in_project,
          work_item_in_other_project
        )

        ensure_elasticsearch_index!
      end

      it 'returns work items only from the specified project' do
        expect(execute).to contain_exactly(work_item_in_project)
      end

      context 'when resource_parent is a private Project' do
        let_it_be(:private_project) { create(:project, :private, namespace: group) }
        let_it_be(:user_without_access) { create(:user) }
        let(:resource_parent) { private_project }

        let_it_be(:work_item_in_private_project) { create(:work_item, project: private_project) }

        before do
          Elastic::ProcessBookkeepingService.track!(work_item_in_private_project)
          ensure_elasticsearch_index!
        end

        context 'when user has no access to private project' do
          let(:finder) { described_class.new(user_without_access, context, resource_parent, params) }

          it 'returns no work items due to insufficient permissions' do
            expect(execute).to be_empty
          end
        end
      end
    end

    context 'when resource_parent is a public Group with mixed project visibility' do
      let_it_be(:public_group) { create(:group, :public) }
      let_it_be(:public_project_in_group) { create(:project, :public, namespace: public_group) }
      let_it_be(:private_project_in_group) { create(:project, :private, namespace: public_group) }
      let_it_be(:user_without_private_access) { create(:user) }

      let(:resource_parent) { public_group }

      let_it_be(:work_item_in_public_project) { create(:work_item, project: public_project_in_group) }
      let_it_be(:work_item_in_private_project) { create(:work_item, project: private_project_in_group) }

      before_all do
        # Give current_user access to both projects,
        # while user_without_private_access has no explicit access to private project
        public_project_in_group.add_reporter(current_user)
        private_project_in_group.add_reporter(current_user)
      end

      before do
        Elastic::ProcessBookkeepingService.track!(
          work_item_in_public_project,
          work_item_in_private_project
        )

        ensure_elasticsearch_index!
      end

      context 'when user has access to both projects' do
        let(:finder) { described_class.new(current_user, context, resource_parent, params) }

        it 'returns work items from both public and private projects' do
          expect(execute).to contain_exactly(work_item_in_public_project, work_item_in_private_project)
        end
      end

      context 'when user has access only to public project' do
        let(:finder) { described_class.new(user_without_private_access, context, resource_parent, params) }

        it 'returns only work items from public project' do
          expect(execute).to contain_exactly(work_item_in_public_project)
        end
      end
    end
  end
end
