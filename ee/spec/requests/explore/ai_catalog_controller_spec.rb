# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Explore::AiCatalogController, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }

  let(:ai_catalog_available) { true }

  describe 'GET #index' do
    let(:path) { explore_ai_catalog_path }

    before do
      allow(Ai::Catalog).to receive(:available?).and_return(ai_catalog_available)
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      it 'responds with success' do
        get path

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'renders the index template' do
        get path

        expect(response).to render_template('index')
      end

      it 'uses the explore layout' do
        get path

        expect(response).to render_template(layout: 'explore')
      end

      context 'when AI Catalog is not available for the instance' do
        let(:ai_catalog_available) { false }

        it 'renders 404' do
          get path

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not signed in' do
      it 'redirects to login page' do
        get path

        expect(response).to redirect_to new_user_session_path
      end
    end
  end
end
