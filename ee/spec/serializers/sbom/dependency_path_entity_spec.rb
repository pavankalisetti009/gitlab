# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DependencyPathEntity, feature_category: :dependency_management do
  let(:dependency_path) do
    Sbom::DependencyPath.new(
      full_path: %w[ancestor_1 ancestor_2 dependency],
      version: ['0.0.1', '0.0.2', '0.0.3'],
      is_cyclic: false,
      max_depth_reached: false
    )
  end

  let(:entity) { described_class.new(dependency_path).as_json }

  it "returns the required attributes" do
    expect(entity).to include(:path, :is_cyclic, :max_depth_reached)
    expect(entity[:path]).to eq([
      { name: 'ancestor_1', version: '0.0.1' },
      { name: 'ancestor_2', version: '0.0.2' },
      { name: 'dependency', version: '0.0.3' }
    ])
  end
end
