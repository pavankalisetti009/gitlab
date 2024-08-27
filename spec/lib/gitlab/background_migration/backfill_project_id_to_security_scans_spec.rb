# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillProjectIdToSecurityScans, feature_category: :vulnerability_management do
  let(:security_scans) { table(:security_scans, database: :sec) }
  let(:ci_builds) { partitioned_table(:p_ci_builds, database: :ci) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }

  let!(:ci_build) { create_ci_build }

  let(:args) do
    min, max = security_scans.pick('MIN(id)', 'MAX(id)')

    {
      start_id: min,
      end_id: max,
      batch_table: 'security_scans',
      batch_column: 'id',
      sub_batch_size: 1,
      pause_ms: 0,
      connection: Gitlab::Database::SecApplicationRecord.connection
    }
  end

  subject(:perform_migration) { described_class.new(**args).perform }

  context 'when security_scan.build_id does not exist' do
    let!(:scan) do
      security_scans.create!(
        build_id: non_existing_record_id,
        scan_type: 1
      )
    end

    it 'deletes the security_scan' do
      expect { perform_migration }.to change { security_scans.count }.from(1).to(0)
    end
  end

  context 'when security_scan is missing project_id' do
    let!(:scan) do
      security_scans.create!(
        build_id: ci_build.id,
        scan_type: 1
      )
    end

    it 'sets the project_id to build.project_id' do
      expect { perform_migration }.to change { scan.reload.project_id }.from(nil).to(ci_build.project_id)
    end
  end

  context 'when security_scan does not need to be changed' do
    let!(:scan) do
      security_scans.create!(
        build_id: ci_build.id,
        project_id: ci_build.project_id,
        scan_type: 1
      )
    end

    it 'does not update the scan' do
      expect { perform_migration }.not_to change { scan.reload.updated_at }
    end
  end

  def create_ci_build
    namespace = namespaces.create!(name: 'gitlab-org', path: 'gitlab-org')
    project_namespace = namespaces.create!(name: 'gitlab', path: 'gitlab')
    project = projects.create!(
      namespace_id: namespace.id,
      project_namespace_id: project_namespace.id,
      name: 'gitlab',
      path: 'gitlab'
    )
    ci_builds.create!(project_id: project.id, partition_id: 100)
  end
end
