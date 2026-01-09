# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettingsController, :enable_admin_mode, feature_category: :shared do
  include StubENV

  let_it_be(:admin) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
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

    context 'for display_gitlab_credits_user_data', feature_category: :consumables_cost_management do
      it 'does not show the checkbox in saas', :saas_gitlab_com_subscriptions do
        stub_feature_flags(usage_billing_dev: true)
        stub_licensed_features(usage_billing: true)

        get general_admin_application_settings_path

        expect(response.body).not_to include('GitLab Credits dashboard')
        expect(response.body).not_to include('Display user data')
      end

      it 'hides checkbox when usage_billing_dev is disabled' do
        stub_feature_flags(usage_billing_dev: false)
        stub_licensed_features(usage_billing: true)

        get general_admin_application_settings_path

        expect(response.body).not_to include('GitLab Credits dashboard')
        expect(response.body).not_to include('Display user data')
      end

      it 'hides checkbox when license does not have usage billing feature' do
        stub_feature_flags(usage_billing_dev: true)
        stub_licensed_features(usage_billing: false)

        get general_admin_application_settings_path

        expect(response.body).not_to include('GitLab Credits dashboard')
        expect(response.body).not_to include('Display user data')
      end

      it 'shows the checkbox when both feature flag and license feature are enabled' do
        stub_feature_flags(usage_billing_dev: true)
        stub_licensed_features(usage_billing: true)

        get general_admin_application_settings_path

        expect(response.body).to include('GitLab Credits dashboard')
        expect(response.body).to include('Display user data')
      end

      it 'shows checkbox as checked when setting is true' do
        stub_feature_flags(usage_billing_dev: true)
        stub_licensed_features(usage_billing: true)
        ::Gitlab::CurrentSettings.update!(display_gitlab_credits_user_data: true)

        get general_admin_application_settings_path

        expect(response.body).to include('display_gitlab_credits_user_data')
        expect(response.body)
          .to include('checked="checked" name="application_setting[display_gitlab_credits_user_data]"')
      end

      it 'shows checkbox as unchecked when setting is false' do
        stub_feature_flags(usage_billing_dev: true)
        stub_licensed_features(usage_billing: true)
        ::Gitlab::CurrentSettings.update!(display_gitlab_credits_user_data: false)

        get general_admin_application_settings_path

        expect(response.body).to include('display_gitlab_credits_user_data')
        expect(response.body)
          .not_to include('checked="checked" name="application_setting[display_gitlab_credits_user_data]"')
      end
    end
  end

  describe 'GET #work_item', feature_category: :team_planning do
    before do
      sign_in(admin)
    end

    it 'renders the work_item settings page' do
      get work_item_admin_application_settings_path

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when user is unauthorized' do
      let(:unauthorized_user) { create(:user) }

      before do
        sign_in(unauthorized_user)
      end

      it 'does not render the page' do
        get work_item_admin_application_settings_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(work_item_configurable_types: false)
      end

      it 'returns 404' do
        get work_item_admin_application_settings_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    before do
      sign_in(admin)
    end

    context 'for display_gitlab_credits_user_data', feature_category: :consumables_cost_management do
      let(:params) do
        { application_setting: { display_gitlab_credits_user_data: display_gitlab_credits_user_data } }
      end

      context 'when updating to true' do
        let(:display_gitlab_credits_user_data) { true }

        it 'updates the setting successfully' do
          patch general_admin_application_settings_path, params: params

          expect(response).to have_gitlab_http_status(:redirect)
          expect(::Gitlab::CurrentSettings.display_gitlab_credits_user_data).to be true
        end

        it 'shows success message' do
          patch general_admin_application_settings_path, params: params

          expect(flash[:notice]).to eq('Application settings saved successfully')
        end
      end

      context 'when updating to false' do
        let(:display_gitlab_credits_user_data) { false }

        before do
          ::Gitlab::CurrentSettings.update!(display_gitlab_credits_user_data: true)
        end

        it 'updates the setting successfully' do
          patch general_admin_application_settings_path, params: params

          expect(response).to have_gitlab_http_status(:redirect)
          expect(::Gitlab::CurrentSettings.display_gitlab_credits_user_data).to be false
        end
      end

      context 'when updating with invalid value' do
        let(:display_gitlab_credits_user_data) { nil }

        it 'does not update the setting' do
          original_value = ::Gitlab::CurrentSettings.display_gitlab_credits_user_data

          patch general_admin_application_settings_path, params: params

          expect(::Gitlab::CurrentSettings.reload.display_gitlab_credits_user_data).to eq(original_value)
        end

        it 'shows error message' do
          patch general_admin_application_settings_path, params: params

          expect(response.body).to include('must be a boolean value')
        end
      end
    end
  end
end
