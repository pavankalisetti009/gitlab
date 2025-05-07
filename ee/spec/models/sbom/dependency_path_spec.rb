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
            dependency_paths = find_dependencies

            aggregate_failures do
              expect(dependency_paths.length).to eq 1
              expect(dependency_paths[0]['full_path']).to match_array([nil, component_1.name, component_2.name])
              expect(dependency_paths[0]['version']).to match_array([nil, component_version_1.version,
                component_version_2.version])
              expect(dependency_paths[0]['is_cyclic']).to be_falsey
              expect(dependency_paths[0]['max_depth_reached']).to be_falsey
            end
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
            dependency_paths = find_dependencies

            aggregate_failures do
              expect(dependency_paths.length).to eq 1
              expect(dependency_paths[0]['full_path']).to match_array([nil, component_1.name, component_2.name,
                component_3.name])
              expect(dependency_paths[0]['version']).to match_array([nil, component_version_1.version,
                component_version_2.version, component_version_3.version])
              expect(dependency_paths[0]['is_cyclic']).to be_falsey
              expect(dependency_paths[0]['max_depth_reached']).to be_falsey
            end
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

        it 'returns itself' do
          dependency_paths = find_dependencies

          aggregate_failures do
            expect(dependency_paths.length).to eq 1
            expect(dependency_paths[0]['full_path']).to match_array([nil, component_1.name])
            expect(dependency_paths[0]['version']).to match_array([nil, component_version_1.version])
            expect(dependency_paths[0]['is_cyclic']).to be_falsey
            expect(dependency_paths[0]['max_depth_reached']).to be_falsey
          end
        end
      end

      context 'when the dependency is both direct and transitive' do
        let_it_be(:component_4) { create(:sbom_component, name: "activerecord") }
        let_it_be(:component_version_4) { create(:sbom_component_version, component: component_4, version: 'v3.4.5') }

        let_it_be(:occurrence_4) do
          create(:sbom_occurrence,
            component: component_4,
            project: project,
            component_version: component_version_4,
            # '{}' element will be present for direct dependencies
            ancestors: [{ name: component_1.name, version: component_version_1.version }, {}]
          )
        end

        let(:occurrence_id) { occurrence_4.id }

        it 'returns both the direct path and the transitive path' do
          paths = find_dependencies.map(&:path)

          expect(paths).to match_array([
            [
              { name: component_1.name, version: component_version_1.version },
              { name: component_4.name, version: component_version_4.version }
            ],
            [
              { name: component_4.name, version: component_version_4.version }
            ]
          ])
        end
      end

      context 'with occurrences which have same component id and component version id' do
        # Occurrence which has same component id and component version id as occurrence_2
        let_it_be(:occurrence_4) do
          create(:sbom_occurrence,
            component: component_2,
            project: project,
            component_version: component_version_2,
            ancestors: [{ name: component_1.name, version: component_version_1.version }]
          )
        end

        let(:occurrence_id) do
          occurrence_3.id
        end

        it 'does not return duplicate paths' do
          paths = find_dependencies.map(&:path)

          expect(paths.size).to eq 1
          expect(paths.first).to eq([
            { name: component_1.name, version: component_version_1.version },
            { name: component_2.name, version: component_version_2.version },
            { name: component_3.name, version: component_version_3.version }
          ])
        end
      end
    end

    context 'with overlapping paths' do
      let_it_be(:occurrence_1) do
        create(:sbom_occurrence,
          component: component_1,
          project: project,
          component_version: component_version_1,
          ancestors: [{}])
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
        dependency_paths = find_dependencies

        aggregate_failures do
          expect(dependency_paths.length).to eq 2

          expect(dependency_paths[0]['full_path']).to match_array([nil, component_1.name, component_3.name])
          expect(dependency_paths[0]['version']).to match_array([nil, component_version_1.version,
            component_version_3.version])
          expect(dependency_paths[0]['is_cyclic']).to be_falsey
          expect(dependency_paths[0]['max_depth_reached']).to be_falsey

          expect(dependency_paths[1]['full_path']).to match_array([nil, component_1.name, component_2.name,
            component_3.name])
          expect(dependency_paths[1]['version']).to match_array([nil, component_version_1.version,
            component_version_2.version, component_version_3.version])
          expect(dependency_paths[1]['is_cyclic']).to be_falsey
          expect(dependency_paths[1]['max_depth_reached']).to be_falsey
        end
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
        dependency_paths = find_dependencies

        aggregate_failures do
          expect(dependency_paths.length).to eq 1

          expect(dependency_paths[0]['full_path']).to match_array([component_3.name, component_1.name, component_2.name,
            component_3.name])
          expect(dependency_paths[0]['version']).to match_array([component_version_3.version,
            component_version_1.version, component_version_2.version, component_version_3.version])
          expect(dependency_paths[0]['is_cyclic']).to be_truthy
          expect(dependency_paths[0]['max_depth_reached']).to be_falsey
        end
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
        stub_const("#{described_class}::MAX_DEPTH", 2)
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
        dependency_paths = find_dependencies
        aggregate_failures do
          expect(dependency_paths.length).to eq 1

          expect(dependency_paths[0]['full_path']).to match_array([component_1.name, component_2.name,
            component_3.name])
          expect(dependency_paths[0]['version']).to match_array([component_version_1.version,
            component_version_2.version, component_version_3.version])
          expect(dependency_paths[0]['is_cyclic']).to be_falsey
          expect(dependency_paths[0]['max_depth_reached']).to be_truthy
        end
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
end
