# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::WorkItemsController, feature_category: :team_planning do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  before do
    stub_licensed_features(work_item_status: true)
    sign_in(user)
  end

  describe 'GET #show' do
    it 'exposes feature flags' do
      get group_settings_issues_path(group)

      expect(response.body).to have_pushed_frontend_feature_flags(workItemStatusFeatureFlag: true)
      expect(response.body).to have_pushed_frontend_feature_flags(workItemStatusMvc2: true)
    end
  end
end
