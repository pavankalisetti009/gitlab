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
end
