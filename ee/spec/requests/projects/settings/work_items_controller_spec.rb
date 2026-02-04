# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::WorkItemsController, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    sign_in(user)
  end

  describe 'GET show' do
    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(work_item_configurable_types: true)
      end

      it 'renders the show template' do
        get project_settings_work_items_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(work_item_configurable_types: false)
      end

      it 'denies access with 403 status' do
        get project_settings_work_items_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
