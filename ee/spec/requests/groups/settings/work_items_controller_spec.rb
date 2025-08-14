# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::WorkItemsController, feature_category: :team_planning do
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

    it 'exposes feature flags' do
      subject

      expect(response.body).to have_pushed_frontend_feature_flags(workItemStatusFeatureFlag: true)
      expect(response.body).to have_pushed_frontend_feature_flags(workItemStatusMvc2: true)
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

      context 'when user is not authorized' do
        it_behaves_like 'unauthorized access'
      end

      context 'when user is authorized' do
        before do
          current_group.add_maintainer(user)
        end

        context 'when custom_fields is available' do
          before do
            stub_licensed_features(custom_fields: true)
          end

          it_behaves_like 'successful access'
        end

        context 'when work_item_status is available' do
          before do
            stub_licensed_features(work_item_status: true)
          end

          it_behaves_like 'successful access'
        end

        context 'when both features are available' do
          before do
            stub_licensed_features(custom_fields: true, work_item_status: true)
          end

          it_behaves_like 'successful access'
        end

        context 'when no licensed features are available' do
          before do
            stub_licensed_features(custom_fields: false, work_item_status: false)
          end

          it_behaves_like 'unauthorized access'
        end
      end
    end
  end
end
