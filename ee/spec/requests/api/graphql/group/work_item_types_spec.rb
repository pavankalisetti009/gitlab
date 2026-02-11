# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of work item types for a group EE', feature_category: :team_planning do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let(:parent) { group }
  let(:current_user) { developer }

  # TODO: Remove this when we enable types provider to return System defined types
  # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/219133
  before do
    stub_feature_flags(work_item_system_defined_type: false)
  end

  it_behaves_like 'graphql work item type list request spec', 'with work item types request context EE'

  it_behaves_like 'graphql work item type list request spec EE'
end
