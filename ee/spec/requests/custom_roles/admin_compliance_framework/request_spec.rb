# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_compliance_framework custom role', feature_category: :compliance_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group, reload: true) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:role) { create(:member_role, :guest, :admin_compliance_framework, namespace: group) }
  let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: current_user, group: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let(:compliance_features) do
    { custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true,
      group_level_compliance_dashboard: true, compliance_framework: true }
  end

  before do
    stub_licensed_features(compliance_features.merge(custom_roles: true))

    sign_in(current_user)
  end

  describe GroupsController do
    it 'user can see edit a group page via a custom role' do
      get edit_group_path(group)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'cannot update the group', :aggregate_failures do
      expect do
        put group_path(group), params: { group: { name: 'new-name' } }

        expect(response).to have_gitlab_http_status(:not_found)
      end.to not_change { group.reload.name }
    end
  end

  describe ProjectsController do
    it 'user can see edit a project page via a custom role' do
      get edit_project_path(project)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:edit)
    end
  end

  describe Projects::ComplianceFrameworksController do
    it 'user can assign a compliance framework to a project via a custom role' do
      params = { framework: framework.id }

      post project_compliance_frameworks_path(project), params: params

      expect(response).to have_gitlab_http_status(:redirect)
      expect(flash[:notice]).to eq("Project '#{project.name}' was successfully updated.")
    end
  end
end
