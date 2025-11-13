# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin > Data Management', :enable_admin_mode, feature_category: :geo_replication do
  let_it_be(:path) { admin_data_management_path }
  let_it_be(:current_user) { create(:admin) }

  before do
    sign_in(current_user)
  end

  describe 'index' do
    it 'renders page', :js do
      visit admin_data_management_path

      expect(page).to have_content(_('Data management'))
    end

    describe 'when `geo_primary_verification_view` flag is disabled' do
      before do
        stub_feature_flags(geo_primary_verification_view: false)

        visit admin_data_management_path
      end

      specify { expect(page.status_code).to eq(404) }
    end
  end

  describe 'show' do
    let_it_be(:model) { create(:project) }
    let_it_be(:show_path) { "#{path}/#{model.class.name}/#{model.id}" }

    it 'renders page', :js do
      visit show_path

      expect(page).to have_content(_('Data management'))
    end

    describe 'when `geo_primary_verification_view` flag is disabled' do
      before do
        stub_feature_flags(geo_primary_verification_view: false)

        visit show_path
      end

      specify { expect(page.status_code).to eq(404) }
    end
  end
end
