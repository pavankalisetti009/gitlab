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

  context 'without cycles' do
    before do
      Sbom::BuildDependencyGraph.execute(project)
    end

    it "returns proper paths for given dependencies", :aggregate_failures do
      expect(described_class.execute(grandgrandchild)).to match_array([
        {
          path: [ancestor, descendant, grandchild, grandgrandchild],
          is_cyclic: false
        }
      ])

      expect(described_class.execute(descendant)).to match_array([
        {
          path: [ancestor, descendant],
          is_cyclic: false
        },
        {
          path: [descendant],
          is_cyclic: false
        }
      ])
    end

    it "adds top level path if the target is a top level dependency" do
      expect(described_class.execute(deep_one)).to match_array([
        {
          path: [ancestor, descendant, grandchild, grandgrandchild, deep_one],
          is_cyclic: false
        },
        {
          path: [deep_one],
          is_cyclic: false
        }
      ])
    end
  end

  context 'with cycles' do
    let_it_be(:cyclic_component_1) do
      create(:sbom_occurrence, input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:cyclic_component_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: cyclic_component_1.component_name, version: cyclic_component_1.version }],
        input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:deep_component) do
      create(:sbom_occurrence,
        ancestors: [{ name: cyclic_component_2.component_name, version: cyclic_component_2.version }],
        input_file_path: ancestor.input_file_path, project: project)
    end

    before do
      cyclic_component_1.update!(
        ancestors: [
          { name: cyclic_component_2.component_name, version: cyclic_component_2.version },
          { name: ancestor.component_name, version: ancestor.version }
        ]
      )

      Sbom::BuildDependencyGraph.execute(project)
    end

    it 'detects cycles' do
      expect(described_class.execute(deep_component)).to match_array([
        {
          path: [ancestor, cyclic_component_1, cyclic_component_2, cyclic_component_1],
          is_cyclic: true
        },
        {
          path: [ancestor, cyclic_component_1, cyclic_component_2, deep_component],
          is_cyclic: false
        }
      ])
    end
  end

  describe "metric collection" do
    before do
      Sbom::BuildDependencyGraph.execute(project)
    end

    it 'records execution time metrics' do
      expect(Gitlab::Metrics).to receive(:measure)
            .with(:build_dependency_paths)
            .and_call_original

      described_class.execute(deep_one)
    end

    it 'records metrics on paths' do
      counter_double = instance_double(Prometheus::Client::Counter)
      expect(Gitlab::Metrics).to receive(:counter)
        .with(:dependency_paths_found, 'Count of Dependency Paths found')
        .and_return(counter_double)

      expect(counter_double).to receive(:increment)
        .with({ cyclic: false }, 2)
      expect(counter_double).to receive(:increment)
        .with({ cyclic: true }, 0)

      described_class.execute(deep_one)
    end
  end
end
