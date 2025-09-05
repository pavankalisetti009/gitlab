# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettingsController, :enable_admin_mode, feature_category: :shared do
  include StubENV

  let_it_be(:admin) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
  end

  describe 'PUT enable_duo_agent_platform', :aggregate_failures, feature_category: :activation do
    let(:params) do
      {
        duo_availability: 'default_on', instance_level_ai_beta_features_enabled: true, duo_core_features_enabled: true
      }
    end

    before_all do
      create(:application_setting, duo_availability: 'default_off')
      create(:ai_settings, duo_core_features_enabled: false)
    end

    subject(:update_request) { put update_duo_agent_platform_admin_application_settings_path(params) }

    context 'when user is admin' do
      before do
        sign_in(admin)
      end

      it 'returns ok status' do
        update_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'enables duo agent platform and feature preview' do
        expect(ApplicationSetting.current).not_to be_instance_level_ai_beta_features_enabled
        expect(ApplicationSetting.current.duo_availability).to eq(:default_off)
        expect(::Ai::Setting.instance).not_to be_duo_core_features_enabled

        update_request

        expect(ApplicationSetting.current).to be_instance_level_ai_beta_features_enabled
        expect(ApplicationSetting.current.duo_availability).to eq(:default_on)
        expect(::Ai::Setting.instance).to be_duo_core_features_enabled
      end

      context 'when only enabling platform' do
        let(:params) { super().except(:instance_level_ai_beta_features_enabled) }

        it 'enables duo agent platform and feature preview' do
          expect(ApplicationSetting.current).not_to be_instance_level_ai_beta_features_enabled
          expect(ApplicationSetting.current.duo_availability).to eq(:default_off)
          expect(::Ai::Setting.instance).not_to be_duo_core_features_enabled

          update_request

          expect(ApplicationSetting.current).not_to be_instance_level_ai_beta_features_enabled
          expect(ApplicationSetting.current.duo_availability).to eq(:default_on)
          expect(::Ai::Setting.instance).to be_duo_core_features_enabled
        end
      end

      context 'when service execution fails' do
        before do
          allow_next_instance_of(::Ai::Agents::UpdatePlatformService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Something went wrong')
            )
          end
        end

        it 'returns unprocessable entity status' do
          update_request

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end

        it 'returns error message in response body' do
          update_request

          expect(response.parsed_body).to eq({ 'message' => 'Something went wrong' })
        end
      end
    end

    context 'when user is not admin' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it 'returns unprocessable entity status' do
        update_request

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'does not enable duo agent platform' do
        update_request

        expect(ApplicationSetting.current).not_to be_instance_level_ai_beta_features_enabled
        expect(ApplicationSetting.current.duo_availability).to eq(:default_off)
        expect(::Ai::Setting.instance).not_to be_duo_core_features_enabled
      end
    end

    context 'when user is not signed in' do
      it 'redirects to sign in page' do
        update_request

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'PUT update_microsoft_application', feature_category: :system_access do
    let(:params) do
      { system_access_microsoft_application: attributes_for(:system_access_microsoft_application) }
    end

    let(:path) { update_microsoft_application_admin_application_settings_path }

    subject(:update_request) { put path, params: params }

    before do
      allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
      sign_in(admin)
    end

    it 'raises an error when parameters are missing' do
      expect { put path }.to raise_error(ActionController::ParameterMissing)
    end

    it 'redirects with error alert when missing required attributes' do
      put path, params: { system_access_microsoft_application: { enabled: true } }

      expect(response).to have_gitlab_http_status(:redirect)
      expect(flash[:alert]).to include('Microsoft Azure integration settings failed to save.')
    end

    it 'redirects with success notice' do
      put path, params: params

      expect(response).to have_gitlab_http_status(:redirect)
      expect(flash[:notice]).to eq(s_('Microsoft|Microsoft Azure integration settings were successfully updated.'))
    end

    it 'creates new SystemAccess::MicrosoftApplication' do
      expect { update_request }.to change { SystemAccess::MicrosoftApplication.count }.by(1)
    end

    it 'does not create a SystemAccess::GroupMicrosoftApplication' do
      expect { update_request }.not_to change { SystemAccess::GroupMicrosoftApplication.count }
    end
  end

  describe 'GET #general', feature_category: :user_management do
    before do
      sign_in(admin)
    end

    context 'when microsoft_group_sync_enabled? is true' do
      before do
        allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
      end

      it 'initializes correctly with SystemAccess::MicrosoftApplication' do
        create(:system_access_microsoft_application, namespace: nil, client_xid: 'test-xid-456')

        get general_admin_application_settings_path

        expect(response.body).to match(/test-xid-456/)
      end
    end

    it 'does push :disable_private_profiles license feature' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:push_licensed_feature).with(:password_complexity)
        expect(instance).to receive(:push_licensed_feature).with(:seat_control)
        expect(instance).to receive(:push_licensed_feature).with(:disable_private_profiles)
      end

      get general_admin_application_settings_path
    end
  end
end
