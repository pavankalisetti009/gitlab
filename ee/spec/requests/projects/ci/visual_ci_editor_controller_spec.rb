# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Ci::VisualCiEditorController, feature_category: :pipeline_composition do
  let_it_be(:user) { create :user }
  let_it_be(:project) { create(:project) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    login_as user
  end

  describe 'GET /*namespace_id/:project_id/ci/visual_ci_editor' do
    context 'with visual_ci_editor feature flag turned on' do
      it 'returns an ok response' do
        get project_ci_visual_ci_editor_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with visual_ci_editor feature flag turned off' do
      before do
        stub_feature_flags(visual_ci_editor: false)
      end

      it 'returns not found' do
        get project_ci_visual_ci_editor_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
