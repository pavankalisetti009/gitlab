# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Members::CustomizableAdminPermissionsEnum, feature_category: :permissions, quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9499' do
  it_behaves_like 'graphql customizable permission'
end
