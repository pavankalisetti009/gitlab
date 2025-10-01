# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin > Data Management', :enable_admin_mode, feature_category: :geo_replication do
  let_it_be(:current_user) { create(:admin) }

  before do
    sign_in(current_user)
  end

  describe 'index' do
    describe 'when `geo_primary_verification_view` flag is enabled', :js do
      before do
        stub_feature_flags(geo_primary_verification_view: true)

        visit admin_data_management_path
      end

      specify { expect(page).to have_content(_('Data management')) }
    end

    describe 'when `geo_primary_verification_view` flag is disabled' do
      before do
        stub_feature_flags(geo_primary_verification_view: false)

        visit admin_data_management_path
      end

      specify { expect(page.status_code).to eq(404) }
    end
  end
end
