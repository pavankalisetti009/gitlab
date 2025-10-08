# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Analytics::DataExplorerController, feature_category: :team_planning do
  let_it_be(:project) { create(:project, :repository, :public, :in_group) }

  describe 'GET index' do
    subject(:request) { get project_analytics_data_explorer_path(project) }

    it 'allows access' do
      request

      expect(response).to have_gitlab_http_status(:success)
    end

    context 'when feature is disabled' do
      before do
        stub_feature_flags(analyze_data_explorer: false)
      end

      it 'renders not found error' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
