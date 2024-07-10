# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_ai_powered', :with_cloud_connector, feature_category: :ai_abstraction_layer do
  let_it_be(:application_setting) { build(:application_setting) }

  before do
    assign(:application_setting, application_setting)
  end

  context 'with `ai_settings_vue_admin` enabled' do
    before do
      stub_feature_flags(ai_settings_vue_admin: true)
    end

    context 'when duo chat is available' do
      before do
        stub_licensed_features(ai_chat: true)
      end

      it 'renders the settings app root' do
        render

        expect(rendered).to have_selector('#js-ai-settings')
        expect(rendered).not_to have_selector('#application_setting_disabled_direct_code_suggestions')
      end

      it 'does not render the haml anchor' do
        expect(rendered).not_to have_selector('#js-ai-powered-settings')
      end
    end
  end

  context 'with `ai_settings_vue_admin` disabled' do
    before do
      stub_feature_flags(ai_settings_vue_admin: false)
    end

    context 'when duo chat is available' do
      before do
        stub_licensed_features(ai_chat: true)
      end

      it 'renders the settings app root' do
        render

        expect(rendered).to have_selector('#js-ai-powered-settings')
        expect(rendered).not_to have_selector('#application_setting_disabled_direct_code_suggestions')
      end
    end

    context 'when duo pro is available' do
      before do
        allow(CloudConnector::AvailableServices)
          .to receive_message_chain(:find_by_name, :purchased?).and_return(true)
      end

      it 'does not render the haml anchor' do
        expect(rendered).not_to have_selector('#js-ai-settings')
      end

      it 'renders the settings app root' do
        render

        expect(rendered).to have_selector('#application_setting_disabled_direct_code_suggestions')
      end
    end
  end
end
