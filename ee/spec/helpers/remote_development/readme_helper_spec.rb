# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::ReadmeHelper, feature_category: :workspaces do
  it 'returns new_workspace_path' do
    # noinspection RubyResolve
    expect(helper.vue_readme_header_additional_data).to include(
      new_workspace_path: new_remote_development_workspace_path
    )
  end
end
