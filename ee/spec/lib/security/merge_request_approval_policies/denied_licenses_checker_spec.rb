# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::MergeRequestApprovalPolicies::DeniedLicensesChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
  let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
  let(:service) { described_class.new(project, pipeline_report, target_branch_report, scan_result_policy_read) }

  subject(:denied_licenses_with_dependencies) { service.denied_licenses_with_dependencies }

  context 'without package exceptions' do
    include_context 'for denied_licenses_checker without package exceptions'

    with_them do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
      let(:license_states) { states }
      let(:licenses) { { policy_state.to_sym => [{ name: policy_license }] } }

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          license_states: license_states,
          licenses: licenses
        )
      end

      before do
        target_branch_licenses.each do |ld|
          target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end

        pipeline_branch_licenses.each do |ld|
          pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end
    end
  end

  context 'with package exceptions' do
    include_context 'for denied_licenses_checker with package exceptions'

    with_them do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
      let(:license_states) { states }
      let(:licenses) do
        { policy_state.to_sym => [{ name: policy_license, packages: { excluding: { purls: excluded_packages } } }] }
      end

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          license_states: license_states,
          licenses: licenses
        )
      end

      before do
        target_branch_licenses.each do |ld|
          target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(purl_type: ld[2], name: ld[3],
            version: ld[4])
        end

        pipeline_branch_licenses.each do |ld|
          pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(purl_type: ld[2], name: ld[3],
            version: ld[4])
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end
    end
  end
end
