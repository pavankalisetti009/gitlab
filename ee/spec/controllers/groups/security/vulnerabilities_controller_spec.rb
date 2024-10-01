# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::VulnerabilitiesController, feature_category: :vulnerability_management do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'GET index' do
    subject(:show_security_dashboard) { get :index, params: { group_id: group.to_param } }

    context 'when security dashboard feature is enabled' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'and user is allowed to access group security vulnerabilities' do
        before do
          group.add_developer(user)
        end

        it { is_expected.to have_gitlab_http_status(:ok) }

        it_behaves_like 'tracks govern usage event', 'users_visiting_security_vulnerabilities' do
          let(:request) { show_security_dashboard }
        end
      end

      context 'when user is not allowed to access group security vulnerabilities' do
        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:unavailable) }

        it_behaves_like "doesn't track govern usage event", 'users_visiting_security_vulnerabilities' do
          let(:request) { show_security_dashboard }
        end
      end
    end

    context 'when security dashboard feature is disabled' do
      it { is_expected.to have_gitlab_http_status(:ok) }
      it { is_expected.to render_template(:unavailable) }

      it_behaves_like "doesn't track govern usage event", 'users_visiting_security_vulnerabilities' do
        let(:request) { show_security_dashboard }
      end
    end

    context "when resolveVulnerabilityWithAi ability is allowed" do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :resolve_vulnerability_with_ai, group).and_return(true)

        show_security_dashboard
      end

      render_views

      it 'sets the frontend ability to true when allowed' do
        expect(response.body).to have_pushed_frontend_ability(resolveVulnerabilityWithAi: true)
      end
    end

    context "when resolveVulnerabilityWithAi ability is not allowed" do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :resolve_vulnerability_with_ai, group).and_return(false)

        show_security_dashboard
      end

      render_views

      it 'sets the frontend ability to false not allowed' do
        expect(response.body).to have_pushed_frontend_ability(resolveVulnerabilityWithAi: false)
      end
    end
  end
end
