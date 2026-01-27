# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container virtual registries and upstreams', :aggregate_failures, feature_category: :virtual_registry do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
    sign_in(user)
  end

  shared_examples 'page is rendered', :js do
    it 'passes accessibility tests' do
      visit url
      wait_for_requests
      expect(page).to be_axe_clean
    end

    it 'redirects to registries' do
      visit url

      expect(page).to have_title('Container registries')
      expect(page).to have_selector('h1', text: 'Container virtual registries')
      expect(page).to have_current_path(/#{group_virtual_registries_container_registries_path(group)}/)
    end

    it 'directly visiting registries route renders registries' do
      visit group_virtual_registries_container_registries_path(group)

      expect(page).to have_title('Container registries')
    end

    context 'when visiting upstreams page' do
      before do
        visit group_virtual_registries_container_upstreams_path(group)
      end

      it 'renders upstreams' do
        expect(page).to have_title('Container upstreams')
        expect(find_by_testid('upstream-name')).to have_text(upstream.name)
      end

      it 'passes axe automated accessibility testing' do
        expect(page).to be_axe_clean
      end
    end

    context 'when visiting upstreams detail page' do
      before do
        visit group_virtual_registries_container_upstream_path(group, upstream.id)
      end

      it 'renders upstreams' do
        expect(find_by_testid('page-heading')).to have_text(upstream.name)
      end

      it 'passes axe automated accessibility testing' do
        expect(page).to be_axe_clean
      end
    end

    it 'sidebar menu is open' do
      visit url
      wait_for_requests

      within_testid 'super-sidebar' do
        expect(page).to have_link('Virtual registry', href: group_virtual_registries_path(group))
      end
    end
  end

  describe 'list page' do
    subject(:url) { group_virtual_registries_container_path(group) }

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

      it_behaves_like 'container virtual registry is unavailable'

      it_behaves_like 'page is rendered'

      context 'with existing virtual registry', :js do
        it 'renders container virtual registries tab without actions to create/edit' do
          visit url

          expect(page).to have_selector('h1', text: 'Container virtual registries')

          expect(page).not_to have_link('Create registry',
            href: new_group_virtual_registries_container_registry_path(group))

          expect(page).not_to have_link('Edit', href:
            edit_group_virtual_registries_container_registry_path(group, registry))
          expect(page).to have_link(registry.name, href:
            /#{group_virtual_registries_container_registry_path(group, registry)}/)
        end

        it 'does not allow editing registry', :js do
          visit edit_group_virtual_registries_container_registry_path(group, registry)

          expect(page).to have_current_path(/#{group_virtual_registries_container_registries_path(group)}/)
        end
      end
    end

    context 'when user is maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'container virtual registry is unavailable'

      it_behaves_like 'page is rendered'

      context 'with existing virtual registry', :js do
        it 'renders container virtual registries tab without actions to create/edit' do
          visit url

          expect(page).to have_selector('h1', text: 'Container virtual registries')

          expect(page).to have_link('Create registry',
            href: new_group_virtual_registries_container_registry_path(group))
          expect(page).to have_link('Edit', href:
            edit_group_virtual_registries_container_registry_path(group, registry))
          expect(page).to have_link(registry.name, href:
            /#{group_virtual_registries_container_registry_path(group, registry)}/)
        end

        it 'edits registry' do
          visit edit_group_virtual_registries_container_registry_path(group, registry)

          fill_in _('Name'), with: 'New Name'
          fill_in _('Description (optional)'), with: 'New description'

          click_button 'Save registry'

          expect(page).to have_content('Registry New Name was successfully updated.')
          expect(page).to have_current_path(
            "#{group_virtual_registries_container_registry_path(group, ::VirtualRegistries::Container::Registry.last)}/"
          )
        end

        it 'deletes virtual registy' do
          visit edit_group_virtual_registries_container_registry_path(group, registry)

          click_button 'Delete registry'

          within_modal do
            click_button 'Delete'
          end

          expect(page).not_to have_text(registry.name)
          expect(page).to have_current_path(/#{group_virtual_registries_container_registries_path(group)}/)
        end
      end

      it 'creates new registry', :js do
        visit new_group_virtual_registries_container_registry_path(group)

        fill_in _('Name'), with: 'New Name'
        fill_in _('Description (optional)'), with: 'New description'

        click_button 'Create registry'

        expect(page).to have_content('Registry New Name was successfully created.')
        expect(page).to have_current_path(
          "#{group_virtual_registries_container_registry_path(group, ::VirtualRegistries::Container::Registry.last)}/"
        )
      end

      context 'with existing virtual registry upstream', :js do
        before do
          visit group_virtual_registries_container_upstreams_path(group)

          wait_for_requests
        end

        it 'deletes upstream' do
          expect(page).to have_text(upstream.name)

          click_button 'More actions'

          click_button 'Delete upstream'

          within_modal do
            click_button 'Delete upstream'
          end

          expect(page).not_to have_text(upstream.name)
          expect(page).to have_text('Upstream has been deleted.')
        end
      end
    end
  end
end
