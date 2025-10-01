# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/data_management/index.html.haml', :enable_admin_mode, feature_category: :geo_replication do
  before do
    allow(view).to receive(:breadcrumb_title)
    allow(view).to receive(:page_title)

    render
  end

  it 'sets page title' do
    expect(view).to have_received(:page_title).with(_('Data management'))
  end

  it 'sets breadcrumbs' do
    expect(view).to have_received(:breadcrumb_title).with(_('Data management'))
  end

  it 'renders #js-admin-data-management' do
    expect(rendered).to have_selector('#js-admin-data-management')
  end
end
