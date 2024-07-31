# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::CreateVulnerabilitiesService, feature_category: :software_composition_analysis do
  describe '.execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:pipeline) { create(:ci_pipeline, user: user) }

    subject(:result) { described_class.execute(pipeline.id) }

    context 'without related occurrences ' do
      it { expect { result }.not_to change { Vulnerability.count } }
    end

    context 'with related occurrences' do
      let_it_be(:occurrences_count) { 5 }
      let_it_be(:occurrences) { create_list(:sbom_occurrence, occurrences_count, pipeline: pipeline) }

      it { expect { result }.not_to change { Vulnerability.count } }

      context 'with affected packages matching name and purl_type only' do
        before do
          occurrences.map do |occ|
            create(:pm_affected_package, purl_type: occ.purl_type, package_name: occ.component_name)
          end
        end

        it { expect { result }.not_to change { Vulnerability.count } }
      end

      context 'with affected packages matching not only name and purl_type but also version' do
        let_it_be(:first_occurrence) { occurrences.first }
        let_it_be(:affected_packages) do
          occurrences.map do |occ|
            create(:pm_affected_package, purl_type: occ.purl_type, package_name: occ.component_name,
              affected_range: ">=#{occ.version}")
          end
        end

        it 'creates vulnerabilities to each advisory related to the occurrences' do
          result

          expect(Vulnerability.all).to match_array([
            have_attributes(
              author_id: user.id,
              project_id: pipeline.project.id,
              state: 'detected',
              confidence: 'unknown',
              report_type: 'dependency_scanning',
              present_on_default_branch: true,
              title: affected_packages[0].advisory.title,
              severity: affected_packages[0].advisory.cvss_v3.severity.downcase,
              finding_description: affected_packages[0].advisory.description,
              solution: affected_packages[0].solution),
            have_attributes(
              author_id: user.id,
              project_id: pipeline.project.id,
              state: 'detected',
              confidence: 'unknown',
              report_type: 'dependency_scanning',
              present_on_default_branch: true,
              title: affected_packages[1].advisory.title,
              severity: affected_packages[1].advisory.cvss_v3.severity.downcase,
              finding_description: affected_packages[1].advisory.description,
              solution: affected_packages[1].solution),
            have_attributes(
              author_id: user.id,
              project_id: pipeline.project.id,
              state: 'detected',
              confidence: 'unknown',
              report_type: 'dependency_scanning',
              present_on_default_branch: true,
              title: affected_packages[2].advisory.title,
              severity: affected_packages[2].advisory.cvss_v3.severity.downcase,
              finding_description: affected_packages[2].advisory.description,
              solution: affected_packages[2].solution),
            have_attributes(
              author_id: user.id,
              project_id: pipeline.project.id,
              state: 'detected',
              confidence: 'unknown',
              report_type: 'dependency_scanning',
              present_on_default_branch: true,
              title: affected_packages[3].advisory.title,
              severity: affected_packages[3].advisory.cvss_v3.severity.downcase,
              finding_description: affected_packages[3].advisory.description,
              solution: affected_packages[3].solution),
            have_attributes(
              author_id: user.id,
              project_id: pipeline.project.id,
              state: 'detected',
              confidence: 'unknown',
              report_type: 'dependency_scanning',
              present_on_default_branch: true,
              title: affected_packages[4].advisory.title,
              severity: affected_packages[4].advisory.cvss_v3.severity.downcase,
              finding_description: affected_packages[4].advisory.description,
              solution: affected_packages[4].solution)
          ])
        end

        context 'with multiple occurrences with different version associated with the same affected package' do
          let_it_be(:component_version) do
            create(:sbom_component_version, component_id: first_occurrence.component_id,
              version: "#{first_occurrence.version}.1")
          end

          let_it_be(:similar_occurrence) do
            create(:sbom_occurrence, component_id: first_occurrence.component_id,
              component_version_id: component_version.id, component_name: first_occurrence.component_name)
          end

          it 'creates vulnerability only to the first occurrence' do
            expect { result }.to change { Vulnerability.count }.by(occurrences_count)
          end
        end

        context 'with multiple affected packages with different advisories associated with a single occurrence' do
          before do
            create(:pm_affected_package, purl_type: first_occurrence.purl_type,
              package_name: first_occurrence.component_name, affected_range: ">=#{first_occurrence.version}")
          end

          it 'creates vulnerability related to both affected packages in relation to the first occurrence' do
            expect { result }.to change { Vulnerability.count }.by(occurrences_count + 1)
          end
        end

        context 'with existing related vulnerability findings' do
          before do
            occurrences.count.times do |i|
              affected_package = affected_packages[i]
              occurrence = occurrences[i]
              location = ::Gitlab::Ci::Reports::Security::Locations::DependencyScanning.new(
                file_path: occurrence.input_file_path,
                package_name: occurrence.component_name,
                package_version: occurrence.version
              )
              identifier = ::Gitlab::Ci::Reports::Security::Identifier.new(
                external_type: "gemnasium",
                external_id: affected_package.advisory.advisory_xid,
                name: nil,
                url: nil)

              primary_identifier = create(:vulnerabilities_identifier, fingerprint: identifier.fingerprint)
              create(:vulnerabilities_finding,
                report_type: :dependency_scanning,
                project_id: pipeline.project.id,
                primary_identifier: primary_identifier,
                location_fingerprint: location.fingerprint)
            end
          end

          it 'does not created new vulnerability findings' do
            expect { result }.not_to change { Vulnerabilities::Finding.count }
          end
        end
      end
    end
  end
end
