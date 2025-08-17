# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects::DuoAgentsPlatform', type: :request, feature_category: :duo_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_developer(user)
    project.project_setting.update!(duo_remote_flows_enabled: true)
  end

  before do
    sign_in(user)
  end

  describe 'GET /:namespace/:project/-/agents' do
    before do
      stub_feature_flags(duo_workflow_in_ci: true)
    end

    context 'when ::Ai::DuoWorkflow is enabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
      end

      it 'renders successfully' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when ::Ai::DuoWorkflow is disabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(false)
      end

      it 'returns 404' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when duo_workflow_in_ci feature is disabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
        stub_feature_flags(duo_workflow_in_ci: false)
      end

      it 'returns 404' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when duo_remote_flows_enabled setting is disabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
        project.project_setting.update!(duo_remote_flows_enabled: false)
      end

      it 'returns 404' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when vueroute is flow-triggers' do
      context 'when user can manage ai flow triggers' do
        let_it_be(:subscription_purchase) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed)
        end

        let_it_be(:subscription_assignment) do
          create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: subscription_purchase)
        end

        before_all do
          project.add_maintainer(user)
        end

        it 'renders successfully' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user cannot manage ai flow triggers' do
        it 'returns 404' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when flow-triggers are requested' do
      context 'when user is not signed in' do
        before do
          sign_out(user)
        end

        it 'redirects to sign in' do
          get project_automate_flow_triggers_path(project)

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context 'when user does not have access to project' do
        let(:other_user) { create(:user) }

        before do
          sign_out(user)
          sign_in(other_user)
        end

        it 'returns 404' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
