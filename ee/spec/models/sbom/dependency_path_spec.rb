# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DependencyPath, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let_it_be(:component_1) { create(:sbom_component, name: "activestorage") }
  let_it_be(:component_version_1) { create(:sbom_component_version, component: component_1, version: 'v1.2.3') }

  let_it_be(:component_2) { create(:sbom_component, name: "activesupport") }
  let_it_be(:component_version_2) { create(:sbom_component_version, component: component_2, version: 'v2.3.4') }

  let_it_be(:component_3) { create(:sbom_component, name: "activejob") }
  let_it_be(:component_version_3) { create(:sbom_component_version, component: component_3, version: 'v3.4.5') }

  subject(:find_dependencies) { described_class.find(occurrence_id: occurrence_id, project_id: project.id) }

  context 'when given a project' do
    context 'without cycles or exceeding the max depth' do
      let_it_be(:occurrence_1) do
        create(:sbom_occurrence,
          component: component_1,
          project: project,
          component_version: component_version_1,
          ancestors: [{}]
        )
      end

      let_it_be(:occurrence_2) do
        create(:sbom_occurrence,
          component: component_2,
          project: project,
          component_version: component_version_2,
          ancestors: [{ name: component_1.name, version: component_version_1.version }]
        )
      end

      let_it_be(:occurrence_3) do
        create(:sbom_occurrence,
          component: component_3,
          project: project,
          component_version: component_version_3,
          ancestors: [{ name: component_2.name, version: component_version_2.version }]
        )
      end

      context 'when ancestors can be found' do
        let(:occurrence_id) do
          occurrence_3.id
        end

        context 'for a dependency with children' do
          let(:occurrence_id) do
            occurrence_2.id
          end

          it 'traverses until it finds no more ancestors, and skips children' do
            is_expected.to eq([described_class.new(
              id: occurrence_2.id,
              project_id: project.id,
              dependency_name: component_2.name,
              full_path: [component_1.name, component_2.name],
              version: [component_version_1.version, component_version_2.version],
              is_cyclic: false,
              max_depth_reached: false
            )])
          end

          it 'returns expected ancestors' do
            expect(find_dependencies[0].path).to eq([
              { name: component_1.name, version: component_version_1.version },
              { name: component_2.name, version: component_version_2.version }
            ])
          end
        end

        context 'for a dependency with no children' do
          let(:occurrence_id) do
            occurrence_3.id
          end

          it 'traverses until it finds no more ancestors' do
            is_expected.to eq([described_class.new(
              id: occurrence_3.id,
              project_id: project.id,
              dependency_name: component_3.name,
              full_path: [component_1.name, component_2.name, component_3.name],
              version: [component_version_1.version, component_version_2.version, component_version_3.version],
              is_cyclic: false,
              max_depth_reached: false
            )])
          end

          it 'returns expected ancestors' do
            expect(find_dependencies[0].path).to eq([
              { name: component_1.name, version: component_version_1.version },
              { name: component_2.name, version: component_version_2.version },
              { name: component_3.name, version: component_version_3.version }
            ])
          end
        end
      end

      context 'when ancestors cannot be found' do
        let(:occurrence_id) do
          occurrence_1.id
        end

        it 'returns an empty array' do
          is_expected.to eq([])
        end
      end
    end

    context 'with overlapping paths' do
      let_it_be(:occurrence_1) do
        create(:sbom_occurrence, component: component_1, project: project, component_version: component_version_1)
      end

      let_it_be(:occurrence_2) do
        create(:sbom_occurrence,
          component: component_2,
          project: project,
          component_version: component_version_2,
          ancestors: [{ name: component_1.name, version: component_version_1.version }]
        )
      end

      let_it_be(:occurrence_3) do
        create(:sbom_occurrence,
          component: component_3,
          project: project,
          component_version: component_version_3,
          ancestors: [
            { name: component_2.name, version: component_version_2.version },
            { name: component_1.name, version: component_version_1.version }
          ]
        )
      end

      let(:occurrence_id) do
        occurrence_3.id
      end

      it 'emits correct overlapping paths' do
        is_expected.to eq([
          described_class.new(
            id: occurrence_3.id,
            project_id: project.id,
            dependency_name: component_3.name,
            full_path: [component_1.name, component_3.name],
            version: [component_version_1.version, component_version_3.version],
            is_cyclic: false,
            max_depth_reached: false
          ),
          described_class.new(
            id: occurrence_3.id,
            project_id: project.id,
            dependency_name: component_3.name,
            full_path: [component_1.name, component_2.name, component_3.name],
            version: [component_version_1.version, component_version_2.version, component_version_3.version],
            is_cyclic: false,
            max_depth_reached: false
          )
        ])
      end

      it 'returns expected ancestors' do
        expect(find_dependencies[0].path).to eq([
          { name: component_1.name, version: component_version_1.version },
          { name: component_3.name, version: component_version_3.version }
        ])
        expect(find_dependencies[1].path).to eq([
          { name: component_1.name, version: component_version_1.version },
          { name: component_2.name, version: component_version_2.version },
          { name: component_3.name, version: component_version_3.version }
        ])
      end
    end

    context 'if there is a cycle' do
      let_it_be(:occurrence_1) do
        create(:sbom_occurrence,
          component: component_1,
          project: project,
          component_version: component_version_1,
          ancestors: [{ name: component_3.name, version: component_version_3.version }]
        )
      end

      let_it_be(:occurrence_2) do
        create(:sbom_occurrence,
          component: component_2,
          project: project,
          component_version: component_version_2,
          ancestors: [{ name: component_1.name, version: component_version_1.version }]
        )
      end

      let_it_be(:occurrence_3) do
        create(:sbom_occurrence,
          component: component_3,
          project: project,
          component_version: component_version_3,
          ancestors: [{ name: component_2.name, version: component_version_2.version }]
        )
      end

      let(:occurrence_id) do
        occurrence_3.id
      end

      it 'traverses until it finds the cycle and stops' do
        is_expected.to eq([described_class.new(
          id: occurrence_3.id,
          project_id: project.id,
          dependency_name: component_3.name,
          full_path: [component_3.name, component_1.name, component_2.name, component_3.name],
          version: [component_version_3.version,
            component_version_1.version, component_version_2.version, component_version_3.version],
          is_cyclic: true,
          max_depth_reached: false
        )])
      end

      it 'returns expected ancestors' do
        expect(find_dependencies[0].path).to eq([
          { name: component_3.name, version: component_version_3.version },
          { name: component_1.name, version: component_version_1.version },
          { name: component_2.name, version: component_version_2.version },
          { name: component_3.name, version: component_version_3.version }
        ])
      end
    end

    context 'if it exceeds the max depth' do
      before do
        stub_const("#{described_class}::MAX_DEPTH", 1)
      end

      let_it_be(:occurrence_1) do
        create(:sbom_occurrence,
          component: component_1,
          project: project,
          component_version: component_version_1,
          ancestors: [{ name: component_3.name, version: component_version_3.version }]
        )
      end

      let_it_be(:occurrence_2) do
        create(:sbom_occurrence,
          component: component_2,
          project: project,
          component_version: component_version_2,
          ancestors: [{ name: component_1.name, version: component_version_1.version }]
        )
      end

      let_it_be(:occurrence_3) do
        create(:sbom_occurrence,
          component: component_3,
          project: project,
          component_version: component_version_3,
          ancestors: [{ name: component_2.name, version: component_version_2.version }]
        )
      end

      let(:occurrence_id) do
        occurrence_3.id
      end

      it 'traverses until it reaches max depth and stops' do
        is_expected.to eq([described_class.new(
          id: occurrence_3.id,
          project_id: project.id,
          dependency_name: component_3.name,
          full_path: [component_2.name, component_3.name],
          version: [component_version_2.version, component_version_3.version],
          is_cyclic: false,
          max_depth_reached: true
        )])
      end

      it 'returns expected ancestors' do
        expect(find_dependencies[0].path).to eq([
          { name: component_2.name, version: component_version_2.version },
          { name: component_3.name, version: component_version_3.version }
        ])
      end
    end
  end
end
