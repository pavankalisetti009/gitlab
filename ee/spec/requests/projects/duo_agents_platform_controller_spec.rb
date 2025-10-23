# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects::DuoAgentsPlatform', type: :request, feature_category: :duo_agent_platform do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before do
    project.add_developer(user)
    project.project_setting.update!(duo_remote_flows_enabled: true, duo_features_enabled: true)

    sign_in(user)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, anything, anything).and_return(true)
  end

  describe 'GET /:namespace/:project/-/automate' do
    before do
      stub_feature_flags(duo_workflow_in_ci: true)
    end

    context 'when ::Ai::DuoWorkflow is enabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
      end

      context 'and the user has access to duo_workflow' do
        it 'renders successfully' do
          get project_automate_agent_sessions_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'and the user does not have access to duo_workflow' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :duo_workflow, project).and_return(false)
        end

        it 'does not render' do
          get project_automate_agent_sessions_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
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

    context 'when duo_workflow_in_ci feature flag is disabled' do
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

    context 'when vueroute is agents' do
      context 'when global_ai_catalog feature is enabled' do
        before do
          stub_feature_flags(global_ai_catalog: true)
        end

        it 'returns successfully' do
          get project_automate_agents_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when the user is not signed in and the project is public' do
          let_it_be(:project) { create(:project, :public) }

          before do
            sign_out(user)
          end

          it 'returns a 404' do
            get project_automate_agents_path(project)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when global_ai_catalog feature is disabled' do
        before do
          stub_feature_flags(global_ai_catalog: false)
        end

        it 'returns 404' do
          get project_automate_agents_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is flow-triggers' do
      context 'when user can manage ai flow triggers' do
        let(:subscription_purchase) do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed)
        end

        let(:subscription_assignment) do
          create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: subscription_purchase)
        end

        before do
          project.add_maintainer(user)
          subscription_assignment # Ensure assignment is created
        end

        it 'renders successfully' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user cannot manage ai flow triggers' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :manage_ai_flow_triggers, project).and_return(false)
        end

        it 'returns 404' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is flows' do
      context 'when ai_catalog_flows feature is enabled' do
        before do
          stub_feature_flags(global_ai_catalog: true, ai_catalog_flows: true, ai_catalog_third_party_flows: false)
        end

        it 'returns successfully' do
          get project_automate_flows_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when ai_catalog_third_party_flows feature is enabled' do
        before do
          stub_feature_flags(global_ai_catalog: true, ai_catalog_flows: false, ai_catalog_third_party_flows: true)
        end

        it 'returns successfully' do
          get project_automate_flows_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when both ai_catalog_flows and ai_catalog_third_party_flows are enabled' do
        before do
          stub_feature_flags(global_ai_catalog: true, ai_catalog_flows: true, ai_catalog_third_party_flows: true)
        end

        it 'returns successfully' do
          get project_automate_flows_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when both ai_catalog_flows and ai_catalog_third_party_flows are disabled' do
        before do
          stub_feature_flags(global_ai_catalog: true, ai_catalog_flows: false, ai_catalog_third_party_flows: false)
        end

        it 'returns 404' do
          get project_automate_flows_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when global_ai_catalog is disabled' do
        before do
          stub_feature_flags(global_ai_catalog: false, ai_catalog_flows: true)
        end

        it 'returns 404' do
          get project_automate_flows_path(project)

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
