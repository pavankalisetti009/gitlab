# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::VirtualRegistriesController, feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  describe 'GET #index' do
    subject { get group_virtual_registries_path(group) }

    it { is_expected.to have_request_urgency(:low) }

    context 'when user is not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when user is signed in' do
      before do
        sign_in(user)
      end

      context 'when user is not a group member' do
        it_behaves_like 'returning response status', :not_found
      end

      context 'when user is group member' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'returning response status', :ok

        context 'when group is not root group' do
          let(:group) { create(:group, :private, parent: super()) }

          it_behaves_like 'returning response status', :not_found
        end

        context 'when the dependency proxy config is disabled' do
          before do
            stub_config(dependency_proxy: { enabled: false })
          end

          it_behaves_like 'returning response status', :not_found
        end

        context 'when license is invalid' do
          before do
            stub_licensed_features(packages_virtual_registry: false)
          end

          it_behaves_like 'returning response status', :not_found
        end

        context 'when feature flag virtual_registry_maven is disabled' do
          before do
            stub_feature_flags(virtual_registry_maven: false)
          end

          it_behaves_like 'returning response status', :not_found
        end

        context 'when feature flag ui_for_virtual_registries is disabled' do
          before do
            stub_feature_flags(ui_for_virtual_registries: false)
          end

          it_behaves_like 'returning response status', :not_found
        end
      end
    end
  end
end
