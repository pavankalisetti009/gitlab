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
  end

  describe 'GET /:group/-/automate' do
    context 'when user has access to duo_workflow' do
      it 'renders successfully' do
        get group_automate_flows_path(group)

        expect(response).to have_gitlab_http_status(:ok)
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

    context 'when vueroute is flows' do
      it 'returns successfully' do
        get group_automate_flows_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when ai_catalog_flows is disabled' do
        before do
          stub_feature_flags(global_ai_catalog: true, ai_catalog_flows: false)
        end

        it 'returns 404' do
          get group_automate_flows_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when global_ai_catalog is disabled' do
        before do
          stub_feature_flags(global_ai_catalog: false, ai_catalog_flows: true)
        end

        it 'returns 404' do
          get group_automate_flows_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
