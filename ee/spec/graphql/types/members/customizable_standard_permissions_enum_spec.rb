# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Members::CustomizableStandardPermissionsEnum, feature_category: :permissions, quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9448' do
  it_behaves_like 'graphql customizable permission'
end
