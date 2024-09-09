# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestOccurrences, feature_category: :dependency_management do
  let_it_be(:default_licenses) do
    [
      { name: 'Apache 2.0 License', spdx_identifier: 'Apache-2.0', url: 'https://spdx.org/licenses/Apache-2.0.html' },
      { name: 'MIT', spdx_identifier: 'MIT', url: 'https://spdx.org/licenses/MIT.html' }
    ]
  end

  let_it_be(:default_license_names) { default_licenses.pluck(:spdx_identifier) }
  let_it_be(:vulnerability) { create(:vulnerability) }
  let_it_be(:pipeline) do
    create(:ci_pipeline, sha: 'b83d6e391c22777fca1ed3012fce84f633d7fed0', project: vulnerability.project)
  end

  let_it_be(:project) { vulnerability.project }
  let_it_be(:dependency_scanning_finding) do
    create(
      :vulnerabilities_finding,
      :with_dependency_scanning_metadata,
      vulnerability: vulnerability,
      pipeline: pipeline
    )
  end

  let_it_be(:container_scanning_finding) do
    create(
      :vulnerabilities_finding,
      :with_container_scanning_metadata,
      vulnerability: vulnerability,
      pipeline: pipeline,
      image: 'docker.io/library/alpine:3.12',
      operating_system: 'Alpine',
      version: '3.12'
    )
  end

  describe '#execute' do
    subject(:task) { described_class.execute(pipeline, occurrence_maps) }

    let(:finding) { dependency_scanning_finding }
    let(:occurrence_maps) { create_list(:sbom_occurrence_map, 4, :for_occurrence_ingestion, vulnerabilities: nil) }

    it_behaves_like 'bulk insertable task'

    it 'is idempotent' do
      expect { task }.to change(Sbom::Occurrence, :count).by(4)
      expect { task }.not_to change(Sbom::Occurrence, :count)
    end

    describe 'attributes' do
      let(:occurrence_maps) { [occurrence_map] }
      let(:vulnerability_component) { create(:ci_reports_sbom_component, name: package_name, version: version) }
      let(:dependency) { finding.location['dependency'] }
      let(:package_name) { dependency['package']['name'] }
      let(:version) { dependency['version'] }
      let(:path) { finding.file }

      let(:occurrence_map) do
        create(
          :sbom_occurrence_map,
          :for_occurrence_ingestion,
          report_component: vulnerability_component,
          report_source: vulnerability_source,
          vulnerabilities: nil
        )
      end

      before do
        occurrence_maps.map(&:report_component).each do |component|
          create(
            :pm_package,
            name: component.name,
            purl_type: component.purl&.type,
            lowest_version: component.version,
            highest_version: component.version,
            default_license_names: default_license_names
          )
        end
      end

      context 'for a dependency scanning occurrence' do
        let(:finding) { dependency_scanning_finding }
        let(:vulnerability_source) { create(:ci_reports_sbom_source, :dependency_scanning, input_file_path: path) }
        let(:expected_attrs) do
          expected_attributes_for(occurrence_map)
            .merge('vulnerability_count' => 1, 'highest_severity' => finding.severity)
            .then { |attrs| hash_including(attrs) }
        end

        it 'sets the correct attributes for the occurrence' do
          task

          expect(Sbom::Occurrence.last&.attributes).to match(expected_attrs)
        end

        context "for each occurrence_map" do
          before do
            allow(occurrence_map).to receive(:vulnerability_ids=).once
          end

          it 'passes an array of vulnerability ids into the occurrence_map' do
            task

            expect(occurrence_map).to have_received(:vulnerability_ids=).with([finding.vulnerability_id])
          end
        end
      end

      context 'for a container scanning occurrence' do
        let(:finding) { container_scanning_finding }
        let(:vulnerability_component) do
          create(:ci_reports_sbom_component, :with_trivy_properties, name: package_name, version: version)
        end

        let(:vulnerability_source) do
          create(
            :ci_reports_sbom_source, :container_scanning,
            image_name: 'docker.io/library/alpine',
            image_tag: '3.12',
            operating_system_name: 'Alpine',
            operating_system_version: '3.12'
          )
        end

        let(:expected_attrs) do
          expected_attributes_for(occurrence_map)
            .merge(
              'package_manager' => vulnerability_component.properties.packager,
              'input_file_path' => 'container-image:docker.io/library/alpine:3.12',
              'vulnerability_count' => 1,
              'highest_severity' => finding.severity
            ).then { |attrs| hash_including(attrs) }
        end

        it 'sets the correct attributes for the occurrence' do
          task

          expect(Sbom::Occurrence.last&.attributes).to match(expected_attrs)
        end

        context "for each occurrence_map" do
          let(:expected_value) { feature_flag_stub ? [finding.vulnerability_id] : nil }

          before do
            allow(occurrence_map).to receive(:vulnerability_ids=).once
          end

          it 'passes an array of vulnerability ids into the occurrence_map' do
            task

            expect(occurrence_map).to have_received(:vulnerability_ids=).with([finding.vulnerability_id])
          end
        end
      end
    end

    context 'when there is an existing occurrence' do
      let(:occurrence_map) { occurrence_maps.first }
      let!(:existing_occurrence) do
        attributes = expected_attributes_for(occurrence_map).symbolize_keys!
        create(:sbom_occurrence, **attributes)
      end

      before do
        component = occurrence_map.report_component

        create(
          :pm_package,
          name: component.name,
          purl_type: component.purl&.type,
          lowest_version: component.version,
          highest_version: component.version,
          default_license_names: default_license_names
        )
      end

      it 'does not create a new record for the existing version' do
        expect { task }.to change(Sbom::Occurrence, :count).by(3)
        expect(occurrence_maps.map(&:occurrence_id)).to match_array([Integer, Integer, Integer,
          existing_occurrence.id])
      end

      context 'when only attributes related to the pipeline have been changed' do
        subject(:task) { described_class.execute(other_pipeline, occurrence_maps) }

        let_it_be(:other_pipeline) do
          create(:ci_pipeline, sha: '5716ca5987cbf97d6bb54920bea6adde242d87e6', project: pipeline.project)
        end

        before do
          existing_occurrence.update!(pipeline: other_pipeline, commit_sha: other_pipeline.sha)
        end

        it 'does not update existing records' do
          expect { task }.not_to change { existing_occurrence.reload.updated_at }
        end
      end

      context 'when attributes not related to the pipeline have been changed' do
        let_it_be(:start_project) { create(:project) }
        let(:start_traversals) { start_project.namespace.traversal_ids }
        let(:traversals) { project.namespace.traversal_ids }

        before do
          existing_occurrence.update!(project: start_project, traversal_ids: start_traversals)
        end

        it 'updates the record' do
          expect { task }.to change { existing_occurrence.reload.project }.from(start_project).to(project)
                               .and change {
                                      existing_occurrence.reload.traversal_ids
                                    }.from(start_traversals).to(traversals)
        end
      end
    end

    context 'when there is no component version' do
      let(:occurrence_maps) do
        create_list(:sbom_occurrence_map, 4, :for_occurrence_ingestion, component_version: nil, vulnerabilities: nil)
      end

      it 'inserts records without the version' do
        expect { task }.to change(Sbom::Occurrence, :count).by(4)
        expect(occurrence_maps).to all(have_attributes(occurrence_id: Integer))
      end

      it 'does not include licenses' do
        task

        expect(Sbom::Occurrence.pluck(:licenses)).to all(be_empty)
      end
    end

    context 'when there is no source package' do
      let(:occurrence_maps) do
        create_list(:sbom_occurrence_map, 4, :for_occurrence_ingestion, source_package: nil, vulnerabilities: nil)
      end

      it 'inserts records without the source package' do
        expect { task }.to change(Sbom::Occurrence, :count).by(4)
        expect(occurrence_maps).to all(have_attributes(occurrence_id: Integer))
      end
    end

    context 'when there is no purl' do
      let(:component) { create(:ci_reports_sbom_component, purl: nil) }
      let(:occurrence_map) do
        create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component, vulnerabilities: nil)
      end

      let(:occurrence_maps) { [occurrence_map] }

      it 'skips licenses for components without a purl' do
        expect { task }.to change(Sbom::Occurrence, :count).by(1)

        expect(Sbom::Occurrence.pluck(:licenses)).to all(be_empty)
      end
    end

    context 'when there are two duplicate occurrences' do
      let(:occurrence_maps) do
        map1 = create(:sbom_occurrence_map, :for_occurrence_ingestion, vulnerabilities: nil)
        map2 = create(:sbom_occurrence_map, vulnerabilities: nil)
        map2.component_id = map1.component_id
        map2.component_version_id = map1.component_version_id
        map2.source_id = map1.source_id

        [map1, map2]
      end

      it 'discards duplicates' do
        expect { task }.to change { ::Sbom::Occurrence.count }.by(1)
        expect(occurrence_maps.size).to eq(1)
        expect(occurrence_maps).to all(have_attributes(occurrence_id: Integer))
      end
    end
  end

  def expected_attributes_for(occurrence_map)
    Gitlab::Database.allow_cross_joins_across_databases(
      url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/480165'
    ) do
      {
        ancestors: occurrence_map.ancestors,
        archived: project.archived,
        commit_sha: pipeline.sha,
        component_id: occurrence_map.component_id,
        component_name: occurrence_map.name,
        component_version_id: occurrence_map.component_version_id,
        input_file_path: occurrence_map.input_file_path,
        licenses: default_licenses,
        package_manager: occurrence_map.packager,
        pipeline_id: pipeline.id,
        project_id: project.id,
        source_id: occurrence_map.source_id,
        source_package_id: occurrence_map.source_package_id,
        traversal_ids: project.namespace.traversal_ids
      }.deep_stringify_keys!
    end
  end
end
