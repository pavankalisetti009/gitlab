# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container virtual registries and upstreams', :aggregate_failures, feature_category: :virtual_registry do
  include Spec::Support::Helpers::ModalHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
    sign_in(user)
  end

  shared_examples 'page is rendered', :js do
    it 'renders page' do
      visit url

      expect(page).to have_title('Virtual registry')
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
    end

    context 'when user is maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'container virtual registry is unavailable'

      it_behaves_like 'page is rendered'
    end
  end
end
