# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Upload, feature_category: :geo_replication do
  describe '.destroy_for_associations!', :sidekiq_inline do
    let_it_be(:vulnerability_export) { create(:vulnerability_export, :with_csv_file) }
    let_it_be(:uploader) { AttachmentUploader }
    let_it_be(:user) { create(:user) }
    let_it_be(:other_upload) { create(:upload, model: user, uploader: uploader.to_s) }

    let_it_be(:records) { Vulnerabilities::Export.where(id: vulnerability_export.id) }

    it 'deletes the file from the file storage', :sidekiq_inline do
      files_to_delete = described_class
                          .where(model: vulnerability_export, uploader: uploader.to_s).all.map(&:absolute_path)

      expect { described_class.destroy_for_associations!(records, uploader) }
        .to change { files_to_delete.map { |f| File.exist?(f) }.uniq }.from([true]).to([false])
    end

    it 'deletes uploads associated with the given records and uploader' do
      expect { described_class.destroy_for_associations!(records, uploader) }
        .to change { Upload.where(model: vulnerability_export, uploader: uploader.to_s).count }
              .from(1).to(0)
    end

    it 'does not delete uploads that are not associated with the given records' do
      expect { described_class.destroy_for_associations!(records, uploader) }
        .not_to change { Upload.where(model: user, uploader: uploader.to_s).count }
    end

    it 'calls begin_fast_destroy and finalize_fast_destroy' do
      expect(described_class).to receive(:begin_fast_destroy).and_call_original
      expect(described_class).to receive(:finalize_fast_destroy).and_call_original

      described_class.destroy_for_associations!(records, uploader)
    end

    context 'when no records are provided' do
      it 'does not delete anything' do
        expect { described_class.destroy_for_associations!(nil, uploader) }
          .not_to change { Upload.count }
      end
    end
  end

  describe '.search' do
    let_it_be(:upload1) { create(:upload, checksum: '85418cc881d37d83c7e681bc43f63731bf0849e06dc59fa8fa2dcf5448a47b8e') }
    let_it_be(:upload2) { create(:upload, checksum: '27988b9096bf85f1a274a458a4ea8c3de143f84bb35ad6f2e4de1df165fa81a3') }
    let_it_be(:upload3) { create(:upload, checksum: '077c81a37eeb5eff42c30ea6f5141dd6bf768787788773aa94022002f4ccdbe5') }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(upload1, upload2, upload3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all records' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        context 'for checksum attribute' do
          it do
            result = described_class.search('077c81a37eeb5eff42c30ea6f5141dd6bf768787788773aa94022002f4ccdbe5')

            expect(result).to contain_exactly(upload3)
          end
        end
      end
    end
  end

  describe 'Geo', feature_category: :geo_replication do
    include EE::GeoHelpers

    describe 'associations' do
      it do
        is_expected
            .to have_one(:upload_state)
            .class_name('Geo::UploadState')
            .inverse_of(:upload)
            .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:upload) }
      let(:unverifiable_model_record) { build(:upload, store: ObjectStorage::Store::REMOTE) }
    end

    describe '#destroy' do
      subject { create(:upload, :namespace_upload, checksum: '8710d2c16809c79fee211a9693b64038a8aae99561bc86ce98a9b46b45677fe4') }

      context 'when running in a Geo primary node' do
        let_it_be(:primary) { create(:geo_node, :primary) }
        let_it_be(:secondary) { create(:geo_node) }

        it 'logs an event to the Geo event log when bulk removal is used', :sidekiq_inline do
          stub_current_geo_node(primary)

          expect { subject.model.destroy! }.to change(Geo::Event.where(replicable_name: :upload, event_name: :deleted), :count).by(1)

          payload = Geo::Event.where(replicable_name: :upload, event_name: :deleted).last.payload

          expect(payload['model_record_id']).to eq(subject.id)
          expect(payload['blob_path']).to eq(subject.relative_path)
          expect(payload['uploader_class']).to eq('NamespaceFileUploader')
        end
      end
    end

    describe 'replication/verification' do
      let_it_be(:organization_1) { create(:organization) }
      let_it_be(:organization_2) { create(:organization) }

      let_it_be(:user_1) { create(:user, :admin, organization: organization_1) }
      let_it_be(:user_2) { create(:user, :admin, organization: organization_2) }

      let_it_be(:group_1) { create(:group, organization: organization_1) }
      let_it_be(:group_2) { create(:group, organization: organization_2) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      # Upload for the root group
      let_it_be(:first_replicable_and_in_selective_sync) { create(:upload, :namespace_upload, model: group_1) }

      # Upload for a project in a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) { create(:upload, :issuable_upload, model: project_2) }

      # Upload for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        create(:upload, :namespace_upload, :object_storage, model: nested_group_1)
      end

      # Upload for a project not in selective sync
      let_it_be(:last_replicable_and_not_in_selective_sync) { create(:upload, :issuable_upload, model: project_3) }

      include_examples 'Geo Framework selective sync behavior' do
        context 'for each parent upload model' do
          using RSpec::Parameterized::TableSyntax

          where(:parent_model_name, :parent_model_factory) do
            'AbuseReport'                                  | [:abuse_report, :with_screenshot]
            'Achievements::Achievement'                    | [:achievement, :with_avatar]
            'Ai::VectorizableFile'                         | [:ai_vectorizable_file]
            'AlertManagement::MetricImage'                 | [:alert_metric_image]
            'Appearance'                                   | [:appearance, :with_logo]
            'BulkImports::ExportUpload'                    | [:bulk_import_export_upload, :with_export_file]
            'Dependencies::DependencyListExport'           | [:dependency_list_export, :with_file]
            'Dependencies::DependencyListExport::Part'     | [:dependency_list_export_part, :exported]
            'DesignManagement::Action'                     | [:design_action, :with_image_v432x230]
            'ImportExportUpload'                           | [:import_export_upload]
            'IssuableMetricImage'                          | [:issuable_metric_image]
            'Namespace'                                    | [:group, :with_avatar]
            'Organizations::OrganizationDetail'            | [:organization_detail]
            'Project'                                      | [:project, :with_avatar]
            'Projects::ImportExport::RelationExportUpload' | [:relation_export_upload]
            'PersonalSnippet'                              | [:personal_snippet, :with_file]
            'Projects::Topic'                              | [:topic, :with_avatar]
            'User'                                         | [:user, :with_avatar]
            'UserPermissionExportUpload'                   | [:user_permission_export_upload, :finished]
            'Vulnerabilities::ArchiveExport'               | [:vulnerability_archive_export, :with_csv_file]
            'Vulnerabilities::Export'                      | [:vulnerability_export, :with_csv_file]
            'Vulnerabilities::Export::Part'                | [:vulnerability_export_part, :with_csv_file]
            'Vulnerabilities::Remediation'                 | [:vulnerabilities_remediation]
          end

          with_them do
            let(:parent_model) { parent_model_name.safe_constantize.new }
            let(:uploads_sharding_keys) { parent_model.uploads_sharding_key.keys }

            before do
              skip_if_upload_primary_key_is_empty
            end

            describe '.replicables_for_current_secondary' do
              let!(:replicable_in_selective_sync) { create_parent_model_upload_replicable(in_selective_sync: true) }
              let!(:replicable_not_in_selective_sync) { create_parent_model_upload_replicable(in_selective_sync: false) }

              context 'with selective sync by namespace' do
                before do
                  secondary.update!(selective_sync_type: 'namespaces', namespaces: [group_1])
                end

                it "returns uploads that belong to the namespaces and others not associated with Namespace or Project" do
                  replicables = described_class.replicables_for_current_secondary(nil)

                  expect(replicables).to include(replicable_in_selective_sync)

                  unless parent_model_name_project_or_namespace
                    expect(replicables).to include(replicable_not_in_selective_sync)
                  end
                end
              end

              context 'with selective sync by organizations' do
                before do
                  secondary.update!(selective_sync_type: 'organizations', organizations: [group_1.organization])
                end

                it "returns uploads that belong to the organization" do
                  replicables = described_class.replicables_for_current_secondary(nil)

                  expect(replicables).to include(replicable_in_selective_sync)
                  expect(replicables).not_to include(replicable_not_in_selective_sync)
                end
              end
            end
          end
        end

        def create_parent_model_upload_replicable(in_selective_sync:)
          model = create(*parent_model_factory, parent_model_factory_params(in_selective_sync))
          model_type = parent_model_name == 'PersonalSnippet' ? 'Snippet' : parent_model_name

          Upload.find_by(model_type: model_type, model_id: model.id)
        end

        def parent_model_factory_params(in_selective_sync)
          if uploads_sharding_keys.include?(:organization_id)
            organization_factory_params(in_selective_sync)
          elsif uploads_sharding_keys.include?(:namespace_id)
            namespace_factory_params(in_selective_sync)
          elsif uploads_sharding_keys.include?(:project_id)
            project_factory_params(in_selective_sync)
          elsif uploads_sharding_keys.include?(:uploaded_by_user_id)
            user_factory_params(in_selective_sync)
          end
        end

        def organization_factory_params(in_selective_sync)
          { organization_id: in_selective_sync ? organization_1.id : organization_2.id }
        end

        def user_factory_params(in_selective_sync)
          { user_id: in_selective_sync ? user_1.id : user_2.id }
        end

        def namespace_factory_params(in_selective_sync)
          if parent_model_name == 'Namespace'
            { parent_id: in_selective_sync ? group_1.id : group_2.id }
          elsif parent_model.respond_to?(:namespace_id)
            { namespace_id: in_selective_sync ? group_1.id : group_2.id }
          else
            { group: in_selective_sync ? group_1 : group_2 }
          end
        end

        def project_factory_params(in_selective_sync)
          if parent_model_name == 'Project'
            { namespace_id: in_selective_sync ? group_1.id : group_2.id }
          else
            { project_id: in_selective_sync ? project_1.id : project_3.id }
          end
        end

        def skip_if_upload_primary_key_is_empty
          return unless uploads_sharding_keys.empty?

          skip "Skipping because the #{parent_model_name} parent model upload sharding key is empty"
        end

        def parent_model_name_project_or_namespace
          %w[Namespace Project].include?(parent_model_name)
        end
      end
    end
  end
end
