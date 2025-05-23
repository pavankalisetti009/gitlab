# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven virtual registry upstreams', feature_category: :virtual_registry do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, group: group, registry: registry) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  describe 'upstream page' do
    subject(:url) { group_virtual_registries_maven_upstream_path(group, upstream) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member' do
      before_all do
        group.add_guest(user)
      end

      it_behaves_like 'virtual registry is unavailable'

      it 'renders upstream show page' do
        visit url

        expect(page).to have_selector('h1', text: upstream.name)
      end
    end
  end

  describe 'edit page' do
    subject(:url) { edit_group_virtual_registries_maven_upstream_path(group, upstream) }

    context 'when user is not group member' do
      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is guest' do
      before_all do
        group.add_guest(user)
      end

      it 'renders 404' do
        visit url

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is a group member' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'virtual registry is unavailable'

      describe 'behaviour', :aggregate_failures, :js do
        it 'allows updation of existing maven upstream' do
          visit url

          expect(page).to have_selector('h1', text: 'Edit upstream')
          fill_in 'Name', with: 'test maven upstream'
          fill_in 'Description (optional)', with: 'This is a test maven upstream'
          fill_in 'Password (optional)', with: 'mypassword1234'
          click_button 'Save changes'

          expect(page).to have_current_path(group_virtual_registries_maven_upstream_path(group, upstream))
          expect(page).to have_title('test maven upstream')
          expect(page).to have_content('Maven upstream has been updated.')
        end

        it 'shows error when virtual upstream name is too long' do
          visit url

          fill_in 'Name', with: 'test maven registry' * 20
          click_button 'Save changes'

          expect(page).to have_content('Request failed with status code 400')
        end

        it 'allows deletion' do
          visit url

          click_button 'Delete upstream'

          within_modal do
            click_button 'Delete'
          end

          expect(page).to have_current_path(group_virtual_registries_maven_registry_path(group, registry))
          expect(page).to have_content('Maven upstream has been deleted.')
        end

        it 'passes accessibility tests' do
          visit url

          wait_for_requests

          expect(page).to be_axe_clean
        end
      end
    end
  end
end
