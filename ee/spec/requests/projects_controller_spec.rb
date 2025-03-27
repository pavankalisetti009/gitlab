# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsController, :with_license, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: user) }

  context 'when Amazon Q is connected' do
    let_it_be(:integration) { create(:amazon_q_integration, instance: false, project: project) }

    let(:params) do
      {
        project: {
          amazon_q_auto_review_enabled: true,
          project_setting_attributes: { duo_features_enabled: 'true' }
        }
      }
    end

    before do
      allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
      sign_in(user)
    end

    it 'changes auto_review_enabled field of the integration' do
      expect { put project_url(project, params) }.to change {
        project.amazon_q_integration.reload.auto_review_enabled
      }.from(false).to(true)
    end
  end
end
