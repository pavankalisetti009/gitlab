# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups::DuoAgentsPlatform', feature_category: :duo_agent_platform do
  let(:group) { create(:group) }
  let(:user) { create(:user) }

  before do
    group.add_developer(user)

    sign_in(user)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :duo_workflow, group).and_return(true)
    allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(true)
  end

  describe 'GET /:group/-/automate' do
    context 'when group is not a root group' do
      let(:group) { create(:group, :nested) }

      it 'returns 404' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has access to duo_workflow' do
      it 'renders successfully' do
        get group_automate_flows_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'pushes feature flags to frontend' do
        get group_automate_flows_path(group)

        expect(response.body).to include('aiCatalogFlows')
        expect(response.body).to include('aiCatalogThirdPartyFlows')
        expect(response.body).to include('gon.ai_duo_agent_platform_ga_rollout')
      end
    end

    context 'when user does not have access to duo_workflow' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :duo_workflow, group).and_return(false)
      end

      it 'does not render' do
        get group_automate_flows_path(group)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when vueroute is agents' do
      it 'returns successfully' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when global_ai_catalog is disabled' do
        before do
          stub_feature_flags(global_ai_catalog: false)
        end

        it 'returns 404' do
          get group_automate_agents_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is flows' do
      it 'returns successfully' do
        get group_automate_flows_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when user can read foundational flows' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(true)
        end

        it 'returns successfully' do
          get group_automate_flows_path(group)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user does not have access to read flows or foundational flows' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_flow, group).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :read_ai_foundational_flow, group).and_return(false)
        end

        it 'does not render' do
          get group_automate_flows_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
