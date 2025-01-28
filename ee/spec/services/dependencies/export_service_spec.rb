# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::ExportService, feature_category: :dependency_management do
  describe '.execute' do
    let(:dependency_list_export) { instance_double(Dependencies::DependencyListExport) }

    subject(:execute) { described_class.execute(dependency_list_export) }

    it 'instantiates a service object and sends execute message to it' do
      expect_next_instance_of(described_class, dependency_list_export) do |service_object|
        expect(service_object).to receive(:execute)
      end

      execute
    end
  end

  describe '#execute' do
    let(:created_status) { 0 }
    let(:running_status) { 1 }
    let(:finished_status) { 2 }
    let(:service_class) { described_class.new(dependency_list_export) }

    before do
      allow(Time).to receive(:current).and_return(Time.new(2023, 11, 14, 0, 0, 0, '+00:00'))
    end

    shared_examples_for 'export service' do |serializer_service|
      subject(:export) { service_class.execute }

      context 'when the export is not in `created` status' do
        let(:status) { running_status }

        it 'does not run the logic' do
          expect { export }.not_to change { dependency_list_export.reload.file.file }.from(nil)
        end
      end

      context 'when the export is in `created` status' do
        let(:status) { created_status }

        before do
          allow(dependency_list_export).to receive(:schedule_export_deletion)
        end

        context 'when the export fails' do
          before do
            allow(serializer_service).to receive(:execute).and_raise('Foo')
          end

          it 'propagates the error, resets the status of the export, and does not schedule deletion job' do
            expect { export }.to raise_error('Foo')
                             .and not_change { dependency_list_export.status }

            expect(dependency_list_export).not_to have_received(:schedule_export_deletion)
          end
        end

        context 'when the export succeeds' do
          before do
            allow(serializer_service).to receive(:execute).with(dependency_list_export).and_return('Foo')
          end

          it 'marks the export as finished' do
            expect { export }.to change { dependency_list_export.status }.from(created_status).to(finished_status)
          end

          it 'attaches the file to export' do
            expect { export }.to change { dependency_list_export.file.read }.from(nil).to('"Foo"')
            expect(dependency_list_export.file.filename).to eq(expected_filename)
          end

          it 'schedules the export deletion' do
            export

            expect(dependency_list_export).to have_received(:schedule_export_deletion)
          end
        end
      end
    end

    context 'when export type is dependency_list' do
      let(:timestamp) { Time.current.utc.strftime('%FT%H%M') }
      let(:export_type) { :dependency_list }

      context 'when the exportable is an organization' do
        subject(:execute) { described_class.new(export).execute }

        let_it_be(:organization) { create(:organization) }
        let_it_be(:project) { create(:project, organization: organization) }
        let_it_be(:occurrences) { create_list(:sbom_occurrence, 2, project: project) }
        let_it_be_with_reload(:export) { create(:dependency_list_export, project: nil, exportable: organization) }
        let(:expected_filename) { "#{organization.to_param}_dependencies_#{timestamp}.csv" }

        before_all do
          project.add_developer(export.author)
        end

        it { expect(execute).to be_present }
        it { expect { execute }.to change { export.file.filename }.to(expected_filename) }

        it 'includes a header in the export file' do
          header = '"Name","Version","Packager","Location"'
          expect { execute }.to change { export.file.read }.to(include(header))
        end

        it 'includes a row for each occurrence' do
          execute

          content = export.file.read
          occurrences.map do |occurrence|
            expect(content).to include(CSV.generate_line([
              occurrence.component_name,
              occurrence.version,
              occurrence.package_manager,
              occurrence.send(:input_file_blob_path)
            ], force_quotes: true))
          end
        end
      end

      context 'when the exportable is a project' do
        let_it_be(:project) { create(:project) }

        let(:expected_filename) do
          [
            project.full_path.parameterize,
            '_dependencies_',
            Time.current.utc.strftime('%FT%H%M'),
            '.',
            'json'
          ].join
        end

        it_behaves_like 'export service', Dependencies::ExportSerializers::ProjectDependenciesService do
          let(:dependency_list_export) do
            create(:dependency_list_export, project: nil, exportable: project, status: status, export_type: export_type)
          end
        end
      end

      context 'when the exportable is a group' do
        let_it_be(:group) { create(:group) }

        let(:expected_filename) do
          [
            group.full_path.parameterize,
            '_dependencies_',
            Time.current.utc.strftime('%FT%H%M'),
            '.',
            'json'
          ].join
        end

        it_behaves_like 'export service', Dependencies::ExportSerializers::GroupDependenciesService do
          let(:dependency_list_export) do
            create(:dependency_list_export, project: nil, exportable: group, status: status, export_type: export_type)
          end
        end
      end
    end

    context 'when export type is sbom' do
      let(:export_type) { :sbom }

      context 'when the exportable is a pipeline' do
        let_it_be(:pipeline) { create(:ci_pipeline) }

        let(:expected_filename) do
          [
            'gl-',
            'pipeline-',
            pipeline.id,
            '-merged-',
            Time.current.utc.strftime('%FT%H%M'),
            '-sbom.',
            'cdx',
            '.',
            'json'
          ].join
        end

        it_behaves_like 'export service', Dependencies::ExportSerializers::Sbom::PipelineService do
          let(:dependency_list_export) do
            create(:dependency_list_export, {
              project: nil,
              exportable: pipeline,
              status: status,
              export_type: export_type
            })
          end
        end
      end
    end
  end
end
