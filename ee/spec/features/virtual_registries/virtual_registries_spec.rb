# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Virtual registries', feature_category: :virtual_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
    sign_in(user)
  end

  describe 'list page' do
    subject(:url) { group_virtual_registries_path(group) }

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

      it_behaves_like 'disallowed access to virtual registries'

      it 'renders virtual registries page' do
        visit url

        expect(page).to have_selector('h1', text: 'Virtual registries')
      end
    end
  end
end
