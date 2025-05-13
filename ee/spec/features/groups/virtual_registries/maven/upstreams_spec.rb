# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven virtual registry upstreams', feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, group: group) }

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

      it 'renders edit maven virtual registry upstream page' do
        visit url

        expect(page).to have_selector('h1', text: 'Edit upstream')
      end
    end
  end
end
