# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DependencyPathsFinder, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  subject(:dependency_paths) { described_class.new(project, params: params).execute }

  describe "#execute" do
    let_it_be(:component_1) { create(:sbom_component, name: "activestorage") }
    let_it_be(:component_version_1) { create(:sbom_component_version, component: component_1, version: '1.2.3') }

    let_it_be(:component_2) { create(:sbom_component, name: "rails") }
    let_it_be(:component_version_2) { create(:sbom_component_version, component: component_2, version: '1.2.3') }

    let_it_be(:occurrence) do
      create(
        :sbom_occurrence,
        component_version: component_version_1,
        component: component_1,
        project: project,
        ancestors: [{ name: component_2.name, version: component_version_2.version }]
      )
    end

    let_it_be(:params) { { occurrence_id: occurrence.id } }

    let(:result) do
      [Sbom::DependencyPath.new(
        id: occurrence.id,
        project_id: project.id,
        dependency_name: component_1.name,
        full_path: [component_2.name, component_1.name],
        version: [component_version_2.version, component_version_1.version],
        is_cyclic: false,
        max_depth_reached: false
      )]
    end

    it "calls find on Sbom::DependencyPath" do
      expect(Sbom::DependencyPath).to receive(:find).with(occurrence_id: params[:occurrence_id],
        project_id: project.id).and_return(result)

      is_expected.to eq(result)
    end
  end
end
