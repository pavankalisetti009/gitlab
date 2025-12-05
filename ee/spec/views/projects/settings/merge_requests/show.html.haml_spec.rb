# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/settings/merge_requests/show', feature_category: :code_review_workflow do
  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:admin) }

  before do
    assign(:project, project)

    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'Duo Code Review' do
    context 'when auto_duo_code_review_settings are available' do
      before do
        allow(project.project_setting).to receive(:duo_features_enabled?).and_return(true)
        allow(project.namespace).to receive(:auto_duo_code_review_settings_available?).and_return(true)
      end

      it 'displays the setting header' do
        render

        expect(rendered).to have_content 'GitLab Duo Code Review'
      end

      it 'displays the setting form', :aggregate_failures do
        render

        expect(rendered).to have_css('input[id=project_project_setting_attributes_auto_duo_code_review_enabled]')
      end
    end

    context 'when auto_duo_code_review_settings are not available' do
      before do
        allow(project.project_setting).to receive(:duo_features_enabled?).and_return(false)
      end

      it 'does not display the setting' do
        render
        expect(rendered).not_to have_content 'GitLab Duo Code Review'
      end
    end
  end
end
