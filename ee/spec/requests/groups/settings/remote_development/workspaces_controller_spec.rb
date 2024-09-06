# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::RemoteDevelopment::WorkspacesController,
  feature_category: :workspaces do
  let_it_be(:user) { create(:user) }
  let(:group) { create(:group, :private) }

  before do
    group.add_developer(user)
    login_as(user)
  end

  subject(:request) { get group_settings_workspaces_path(group) }

  shared_examples 'index responds not found status' do
    it 'responds with the not found status' do
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    context 'when user can read remote agent mapping configuration' do
      context 'with remote_development_namespace_agent_authorization feature flag on' do
        before do
          stub_feature_flags(remote_development_namespace_agent_authorization: true)
        end

        context 'with remote development feature licensed' do
          before do
            stub_licensed_features(remote_development: true)
          end

          it "responds OK status" do
            request

            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context 'with remote development not licensed' do
          before do
            stub_licensed_features(remote_development: false)
          end

          it_behaves_like 'index responds not found status'
        end
      end

      context 'with remote_development_namespace_agent_authorization feature flag off' do
        before do
          stub_feature_flags(remote_development_namespace_agent_authorization: false)
        end

        it_behaves_like 'index responds not found status'

        context 'with remote development feature licensed' do
          before do
            stub_licensed_features(remote_development: true)
          end

          it_behaves_like 'index responds not found status'
        end
      end
    end
  end
end
