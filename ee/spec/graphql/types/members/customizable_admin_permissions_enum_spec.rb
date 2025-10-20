# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Members::CustomizableAdminPermissionsEnum, feature_category: :permissions, quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/552228' do
  it_behaves_like 'graphql customizable permission'
end
