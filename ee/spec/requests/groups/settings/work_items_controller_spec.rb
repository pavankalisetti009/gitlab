# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::WorkItemsController, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  shared_examples 'successful access' do
    it 'returns 200' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  shared_examples 'unauthorized access' do
    it 'returns 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET #show' do
    subject { get group_settings_issues_path(current_group) }

    context 'with subgroup' do
      let(:current_group) { subgroup }

      before do
        current_group.add_maintainer(user)
        stub_licensed_features(custom_fields: true, work_item_status: true)
      end

      it_behaves_like 'unauthorized access'
    end

    context 'with root group' do
      let(:current_group) { group }

      where(:user_role, :custom_fields_licensed, :work_item_status_licensed, :expected_result) do
        # Maintainer+ roles should have access when at least one licensed feature is enabled
        :maintainer | true  | true  | 'successful access'
        :maintainer | true  | false | 'successful access'
        :maintainer | false | true  | 'successful access'
        :maintainer | false | false | 'unauthorized access'
        :owner      | true  | true  | 'successful access'
        :owner      | true  | false | 'successful access'
        :owner      | false | true  | 'successful access'
        :owner      | false | false | 'unauthorized access'

        # Other roles should never have access regardless of licensed features
        :anonymous  | true  | true  | 'unauthorized access'
        :anonymous  | false | false | 'unauthorized access'
        :guest      | true  | true  | 'unauthorized access'
        :guest      | false | false | 'unauthorized access'
        :developer  | true  | true  | 'unauthorized access'
        :developer  | false | false | 'unauthorized access'
      end

      with_them do
        before do
          case user_role
          when :anonymous
            sign_out(user)
          when :guest
            current_group.add_guest(user)
          when :developer
            current_group.add_developer(user)
          when :maintainer
            current_group.add_maintainer(user)
          when :owner
            current_group.add_owner(user)
          end

          stub_licensed_features(
            custom_fields: custom_fields_licensed, work_item_status: work_item_status_licensed
          )
        end

        it_behaves_like params[:expected_result]
      end

      context 'with work item feature flags' do
        before do
          current_group.add_owner(user)
          stub_licensed_features(custom_fields: true, work_item_status: true)
        end

        context 'when work_items_consolidated_list is disabled' do
          before do
            stub_feature_flags(work_item_planning_view: false)
          end

          it 'pushes work_item_planning_view feature flag' do
            get group_settings_issues_path(current_group)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to have_pushed_frontend_feature_flags(workItemPlanningView: false)
          end
        end

        context 'when work_items_consolidated_list is enabled' do
          before do
            stub_feature_flags(work_item_planning_view: true)
          end

          it 'pushes work_item_planning_view feature flag as true' do
            get group_settings_issues_path(current_group)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.body).to have_pushed_frontend_feature_flags(workItemPlanningView: true)
          end
        end
      end
    end
  end
end
