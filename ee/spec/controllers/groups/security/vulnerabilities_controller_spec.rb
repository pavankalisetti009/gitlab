# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::VulnerabilitiesController, feature_category: :vulnerability_management do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'GET index' do
    subject { get :index, params: { group_id: group.to_param } }

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
          let(:request) { subject }
        end
      end

      context 'when user is not allowed to access group security vulnerabilities' do
        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:unavailable) }

        it_behaves_like "doesn't track govern usage event", 'users_visiting_security_vulnerabilities' do
          let(:request) { subject }
        end
      end
    end

    context 'when security dashboard feature is disabled' do
      it { is_expected.to have_gitlab_http_status(:ok) }
      it { is_expected.to render_template(:unavailable) }

      it_behaves_like "doesn't track govern usage event", 'users_visiting_security_vulnerabilities' do
        let(:request) { subject }
      end
    end

    shared_examples 'resolveVulnerabilityWithAi ability' do |allowed|
      let(:request) { subject }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :resolve_vulnerability_with_ai, group).and_return(allowed)
        request
      end

      render_views

      it "sets the frontend ability to #{allowed}" do
        expect(response.body).to have_pushed_frontend_ability(resolveVulnerabilityWithAi: allowed)
      end
    end

    context "when resolveVulnerabilityWithAi ability is allowed" do
      it_behaves_like 'resolveVulnerabilityWithAi ability', true
    end

    context "when resolveVulnerabilityWithAi ability is not allowed" do
      it_behaves_like 'resolveVulnerabilityWithAi ability', false
    end
  end
end
