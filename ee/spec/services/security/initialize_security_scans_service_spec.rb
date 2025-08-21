# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::InitializeSecurityScansService, feature_category: :vulnerability_management do
  let_it_be_with_reload(:build) { create(:ci_build) }

  subject(:execute) { described_class.execute(build) }

  context 'when build contains all reports' do
    let_it_be(:all_file_types) { EE::Enums::Ci::JobArtifact.security_report_file_types }

    before_all do
      all_file_types.each do |file_type|
        create(:ee_ci_job_artifact, job: build, file_type: file_type, file_format: :raw)
      end

      create(:ee_ci_job_artifact, job: build, file_type: :cyclonedx, file_format: :gzip)
    end

    it 'stores scans for each file type' do
      expect { execute }.to change { Security::Scan.count }.from(0).to(all_file_types.size)
      expect(Security::Scan.all).to all(be_created)
    end

    context 'when a scan already exists' do
      let_it_be(:existing_scan) { create(:security_scan, build: build, status: :preparing) }

      it 'does not reset status' do
        expect { execute }.not_to change { existing_scan.reload.status }
      end
    end
  end

  context 'when build contains only a cyclonedx report' do
    before_all do
      create(:ee_ci_job_artifact, job: build, file_type: :cyclonedx, file_format: :gzip)
    end

    it 'creates a dependency_scanning scan' do
      expect { execute }.to change { Security::Scan.count }.from(0).to(1)
      expect(Security::Scan.first.scan_type).to eq('dependency_scanning')
    end
  end
end
