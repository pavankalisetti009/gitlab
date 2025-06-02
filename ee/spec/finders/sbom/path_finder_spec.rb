# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::PathFinder, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:ancestor) { create(:sbom_occurrence, project: project) }
  let_it_be(:descendant) do
    create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
      input_file_path: ancestor.input_file_path, project: project)
  end

  let_it_be(:grandchild) do
    create(:sbom_occurrence, ancestors: [{ name: descendant.component_name, version: descendant.version }],
      input_file_path: descendant.input_file_path, project: project)
  end

  let_it_be(:grandgrandchild) do
    create(:sbom_occurrence, ancestors: [{ name: grandchild.component_name, version: grandchild.version }],
      input_file_path: grandchild.input_file_path, project: project)
  end

  let_it_be(:deep_one) do
    create(:sbom_occurrence, ancestors: [{ name: grandgrandchild.component_name, version: grandgrandchild.version },
      {}], input_file_path: grandgrandchild.input_file_path, project: project)
  end

  before do
    Sbom::BuildDependencyGraph.execute(project)
  end

  it "returns proper paths for given dependencies", :aggregate_failures do
    expect(described_class.execute(grandgrandchild)).to match_array([
      [ancestor, descendant, grandchild, grandgrandchild]
    ])

    expect(described_class.execute(descendant)).to match_array([
      [descendant],
      [ancestor, descendant]
    ])

    expect(described_class.execute(deep_one)).to match_array([
      [ancestor, descendant, grandchild, grandgrandchild, deep_one],
      [deep_one]
    ])
  end
end
