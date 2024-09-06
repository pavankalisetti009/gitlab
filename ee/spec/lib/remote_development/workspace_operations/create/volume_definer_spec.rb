# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::VolumeDefiner, feature_category: :workspaces do
  let(:context) { { params: 1 } }

  subject(:returned_value) do
    described_class.define(context)
  end

  it "merges volume mount info to passed context" do
    expect(returned_value).to eq(
      {
        params: 1,
        volume_mounts: {
          data_volume: {
            name: "gl-workspace-data",
            path: "/projects"
          }
        }
      }
    )
  end
end
