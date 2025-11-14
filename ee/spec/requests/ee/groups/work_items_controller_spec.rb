# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Level Work Items', feature_category: :team_planning do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:work_item) { create(:work_item, :group_level, namespace: group) }

  describe 'GET /groups/:group/-/work_items/:iid' do
    let(:iid) { work_item.iid }

    subject(:show) { get group_work_item_path(group, iid) }

    before do
      sign_in(current_user)
      stub_licensed_features(epics: true)
    end

    it 'renders show' do
      show

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when the new page gets requested' do
      context 'when work item type is epic' do
        let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

        context 'when work_item_planning_view feature flag is disabled' do
          before do
            stub_feature_flags(work_item_planning_view: false)
          end

          it 'redirects to /epic/:iid' do
            show

            expect(response).to redirect_to(group_epic_path(group, work_item.iid))
          end
        end
      end

      context 'when the new page gets requested' do
        let(:iid) { 'new' }

        it 'renders show' do
          show

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:show)
        end
      end

      context 'when it has no epic license' do
        before do
          stub_licensed_features(epics: false)
        end

        let(:iid) { 'new' }

        it 'renders show' do
          show

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when epic feature is disabled' do
      before do
        stub_licensed_features(epics: false)
      end

      context 'when work item type is epic' do
        let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

        context 'when work_item_planning_view feature flag is disabled' do
          before do
            stub_feature_flags(work_item_planning_view: false)
          end

          it 'redirects to /work_item/:iid' do
            show

            expect(response).to redirect_to(group_epic_path(group, work_item.iid))
          end
        end
      end

      context 'when work item does not exist' do
        let(:iid) { non_existing_record_id }

        it 'renders not found' do
          show

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when work item type is not epic' do
        let_it_be(:work_item) { create(:work_item, :issue, namespace: group) }

        it 'returns not found' do
          show

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe 'GET /groups/:group/-/work_items.atom' do
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:project_work_item) { create(:work_item, project: project) }
      let_it_be(:group_work_item) { create(:work_item, :group_level, namespace: group) }

      let(:current_user) { create(:user, developer_of: group) }
      let(:rss_path) do
        url_for(controller: 'groups/work_items', action: :rss, group_id: group.full_path, format: :atom)
      end

      before do
        sign_in(current_user)
      end

      it 'includes both group-level and project-level work items' do
        get rss_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template('groups/work_items/rss')
        expect(assigns(:work_items)).to include(group_work_item, project_work_item)
      end
    end
  end
end
