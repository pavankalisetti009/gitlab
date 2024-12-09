# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::AmazonQSettingsController, :enable_admin_mode, feature_category: :ai_abstraction_layer do
  let(:admin) { create(:admin) }

  let(:actual_view_model) do
    Gitlab::Json.parse(
      Nokogiri::HTML(response.body).css('#js-amazon-q-settings').first['data-view-model']
    )
  end

  before do
    stub_licensed_features(amazon_q: true)
    stub_feature_flags(amazon_q_integration: true)

    stub_ee_application_setting(duo_availability: 'default_on')

    # NOTE: Updating this singleton in the top-level before each for increasing predictability with tests
    Ai::Setting.instance.update!(
      amazon_q_ready: true,
      amazon_q_role_arn: 'test-arn'
    )

    sign_in(admin)
  end

  shared_examples 'returns 404 when feature is unavailable' do
    before do
      stub_licensed_features(amazon_q: false)
    end

    it 'returns 404' do
      perform_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    let(:perform_request) { get admin_ai_amazon_q_settings_path }

    it_behaves_like 'returns 404 when feature is unavailable'

    it 'renders the frontend entrypoint with view model' do
      perform_request

      expect(actual_view_model).to eq({
        "amazonQSettings" => {
          "availability" => 'default_on',
          "ready" => true,
          "roleArn" => 'test-arn'
        },
        "submitUrl" => admin_ai_amazon_q_settings_path
      })
    end
  end
end
