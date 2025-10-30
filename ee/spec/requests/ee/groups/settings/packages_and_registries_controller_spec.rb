# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::PackagesAndRegistriesController, feature_category: :package_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(packages: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  describe 'GET #show' do
    subject(:request) { get group_settings_packages_and_registries_path(group) }

    context 'when user is not authorized' do
      it_behaves_like 'returning response status', :not_found
    end

    context 'when user is authorized' do
      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'returning response status', :ok

      it_behaves_like 'pushed feature flag', :maven_virtual_registry
      it_behaves_like 'pushed feature flag', :ui_for_virtual_registries
      it_behaves_like 'pushed feature flag', :ui_for_virtual_registry_cleanup_policy

      context 'with adminVirtualRegistry' do
        it 'pushes ability to frontend' do
          request

          expect(response.body).to have_pushed_frontend_ability(adminVirtualRegistry: true)
        end
      end

      context 'with licensed feature' do
        it 'pushes packages_virtual_registry feature' do
          request

          expect(response.body).to have_pushed_licensed_features(packagesVirtualRegistry: true)
        end
      end
    end
  end
end
