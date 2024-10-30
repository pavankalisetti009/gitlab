# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::SelfHostedModelsController, :enable_admin_mode, feature_category: :"self-hosted_models" do
  let(:admin) { create(:admin) }
  let(:duo_features_enabled) { true }

  before do
    sign_in(admin)
    stub_ee_application_setting(duo_features_enabled: duo_features_enabled)

    allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
  end

  shared_examples 'must accept terms and conditions' do
    context 'when terms have not been accepted' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
      end

      it 'redirects to terms page' do
        perform_request

        expect(response).to redirect_to(admin_ai_terms_and_conditions_url)
      end
    end
  end

  shared_examples 'returns 404' do
    context 'when ai_custom_model feature flag is disabled' do
      before do
        stub_feature_flags(ai_custom_model: false)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user is not authorized' do
      it 'performs the right authorization correctly' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(admin, :manage_ai_settings).and_return(false)

        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #edit' do
    let(:page) { Nokogiri::HTML(response.body) }
    let(:self_hosted_model) do
      create(:ai_self_hosted_model, model: :mistral, api_token: nil)
    end

    subject :perform_request do
      get edit_admin_ai_self_hosted_model_path(self_hosted_model)
    end

    it 'returns the self-hosted model for edit' do
      perform_request

      expect(response).to have_gitlab_http_status(:ok)

      expect(assigns(:self_hosted_model)).to eq(self_hosted_model)
    end

    it_behaves_like 'returns 404'
    it_behaves_like 'must accept terms and conditions'
  end
end
