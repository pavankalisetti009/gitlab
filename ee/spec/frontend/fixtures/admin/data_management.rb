# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::DataManagement, '(JavaScript fixtures)', :geo,
  type: :request, feature_category: :geo_replication do
  include ApiHelpers
  include JavaScriptFixturesHelpers
  include EE::GeoHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:node) { create(:geo_node) }
  let_it_be(:snippet_repository) { create(:snippet_repository, :verification_succeeded) }

  before do
    stub_current_geo_node(node)
  end

  it 'api/admin/data_management/snippet_repository.json' do
    get api("/admin/data_management/snippet_repository", admin, admin_mode: true)

    expect(response).to be_successful
  end
end
