# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserSettings::SshKeysController, feature_category: :source_code_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:enterprise_user) { create(:user, enterprise_group_id: group.id) }
  let_it_be(:regular_user) { create(:user, :with_namespace) }

  before do
    stub_licensed_features(disable_ssh_keys: true)
    stub_saas_features(disable_ssh_keys: true)
    stub_feature_flags(enterprise_disable_ssh_keys: true)
  end

  describe 'SSH key disabling for enterprise users' do
    context 'when group has SSH keys disabled' do
      before do
        group.namespace_settings.update!(disable_ssh_keys: true)
      end

      it 'blocks access to SSH key management for enterprise users' do
        login_as(enterprise_user)

        get user_settings_ssh_keys_path
        expect(response).to have_gitlab_http_status(:not_found)

        post user_settings_ssh_keys_path, params: { key: build(:key).attributes }
        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'does not block non-enterprise users' do
        login_as(regular_user)

        component_double = instance_double(Namespaces::Storage::NamespaceLimit::PreEnforcementAlertComponent,
          render?: false,
          render_in: nil)
        allow(Namespaces::Storage::NamespaceLimit::PreEnforcementAlertComponent)
          .to receive(:new).and_return(component_double)

        get user_settings_ssh_keys_path
        expect(response).to have_gitlab_http_status(:ok)

        post user_settings_ssh_keys_path, params: { key: build(:key).attributes }
        expect(response).to have_gitlab_http_status(:found)
      end
    end
  end
end
