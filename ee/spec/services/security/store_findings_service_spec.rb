# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreFindingsService, feature_category: :vulnerability_management do
  let_it_be(:findings_partition_number) { Security::Finding.active_partition_number }
  let_it_be(:security_scan) { create(:security_scan, findings_partition_number: findings_partition_number) }
  let_it_be(:project) { security_scan.project }
  let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
  let_it_be(:security_finding_1) { build(:ci_reports_security_finding) }
  let_it_be(:security_finding_2) { build(:ci_reports_security_finding) }
  let_it_be(:security_finding_3) { build(:ci_reports_security_finding) }
  let_it_be(:security_finding_4) { build(:ci_reports_security_finding, uuid: nil) }
  let_it_be(:deduplicated_finding_uuids) { [security_finding_1.uuid, security_finding_3.uuid] }
  let_it_be(:security_scanner) { build(:ci_reports_security_scanner) }
  let_it_be(:report) do
    build(
      :ci_reports_security_report,
      findings: [security_finding_1, security_finding_2, security_finding_3, security_finding_4],
      scanner: security_scanner
    )
  end

  describe '#execute' do
    let(:service_object) { described_class.new(security_scan, scanner, report, deduplicated_finding_uuids) }

    subject(:store_findings) { service_object.execute }

    context 'when the given security scan already has findings' do
      before do
        create(:security_finding, scan: security_scan)
      end

      it 'returns error message' do
        expect(store_findings).to eq({ status: :error, message: "Findings are already stored!" })
      end

      it 'does not create new findings in database' do
        expect { store_findings }.not_to change(Security::Finding, :count)
      end
    end

    context 'when the given security scan does not have any findings' do
      before do
        security_scan.findings.delete_all
      end

      it 'creates the security finding entries in database' do
        store_findings

        expect(security_scan.findings.reload.as_json(only: [:partition_number, :uuid, :deduplicated]))
          .to match_array(
            [
              {
                "partition_number" => findings_partition_number,
                "uuid" => security_finding_1.uuid,
                "deduplicated" => true
              },
              {
                "partition_number" => findings_partition_number,
                "uuid" => security_finding_2.uuid,
                "deduplicated" => false
              },
              {
                "partition_number" => findings_partition_number,
                "uuid" => security_finding_3.uuid,
                "deduplicated" => true
              }
            ])
      end

      it 'stores raw_source_code_extract from original_data in database' do
        store_findings

        expect(security_scan.findings.reload.as_json(only: :finding_data)).to include(
          a_hash_including(
            "finding_data" => a_hash_including("raw_source_code_extract" => security_finding_1.raw_source_code_extract)
          ),
          a_hash_including(
            "finding_data" => a_hash_including("raw_source_code_extract" => security_finding_2.raw_source_code_extract)
          ),
          a_hash_including(
            "finding_data" => a_hash_including("raw_source_code_extract" => security_finding_3.raw_source_code_extract)
          )
        )
      end

      context 'when findings have CVE identifiers' do
        let_it_be(:cve_identifier_1) do
          build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-1234')
        end

        let_it_be(:cve_identifier_2) do
          build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-5678')
        end

        let_it_be(:cve_identifier_3) do
          build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-8910')
        end

        let_it_be(:non_cve_identifier) { build(:ci_reports_security_identifier, external_type: 'cwe', name: 'CWE-79') }
        let_it_be(:cve_enrichment_1) { create(:pm_cve_enrichment, cve: 'CVE-2024-1234') }
        let_it_be(:cve_enrichment_2) { create(:pm_cve_enrichment, cve: 'CVE-2024-5678', is_known_exploit: false) }
        let_it_be(:cve_enrichment_3) { create(:pm_cve_enrichment, cve: 'CVE-2024-8910', epss_score: 0.9) }

        let_it_be(:security_finding_with_cve_1) do
          build(:ci_reports_security_finding, identifiers: [cve_identifier_1, non_cve_identifier])
        end

        let_it_be(:security_finding_with_cve_2) do
          build(:ci_reports_security_finding, identifiers: [cve_identifier_2, cve_identifier_3])
        end

        let_it_be(:security_finding_without_cve) do
          build(:ci_reports_security_finding, identifiers: [non_cve_identifier])
        end

        let_it_be(:report_with_cves) do
          build(
            :ci_reports_security_report,
            findings: [security_finding_with_cve_1, security_finding_with_cve_2, security_finding_without_cve],
            scanner: security_scanner
          )
        end

        let(:deduplicated_finding_uuids) { [] }

        let(:service_object) do
          described_class.new(security_scan, scanner, report_with_cves, deduplicated_finding_uuids)
        end

        it 'creates finding enrichment records for CVE identifiers' do
          expect { store_findings }.to change(Security::FindingEnrichment, :count).by(3)

          enrichments = Security::FindingEnrichment.where(project: project)
          expect(enrichments.pluck(:cve)).to match_array(%w[CVE-2024-1234 CVE-2024-5678 CVE-2024-8910])
        end

        it 'associates enrichments with security findings and CVE enrichment records' do
          store_findings

          finding_2 = Security::Finding.find_by(uuid: security_finding_with_cve_2.uuid)

          expect(finding_2.finding_enrichments.pluck(:cve)).to contain_exactly('CVE-2024-5678', 'CVE-2024-8910')
          expect(finding_2.finding_enrichments.pluck(:cve_enrichment_id)).to match_array(
            [cve_enrichment_2.id, cve_enrichment_3.id]
          )
          expect(finding_2.finding_enrichments.pluck(:epss_score)).to match_array(
            [cve_enrichment_2.epss_score, cve_enrichment_3.epss_score]
          )
          expect(finding_2.finding_enrichments.pluck(:is_known_exploit)).to match_array(
            [cve_enrichment_2.is_known_exploit, cve_enrichment_3.is_known_exploit]
          )
        end

        it 'does not create enrichments for non-CVE identifiers' do
          store_findings

          finding_without_cve = Security::Finding.find_by(uuid: security_finding_without_cve.uuid)
          expect(finding_without_cve.finding_enrichments).to be_empty
        end

        context 'when finding enrichment already exists' do
          before do
            create(:security_finding, uuid: security_finding_with_cve_1.uuid)
            Security::FindingEnrichment.create!(
              project: project,
              finding_uuid: security_finding_with_cve_1.uuid,
              cve_enrichment: cve_enrichment_1,
              cve: 'CVE-2024-1234'
            )
          end

          it 'does not create duplicate enrichment records for already existing finding uuid' do
            expect { store_findings }.to change(Security::FindingEnrichment, :count).by(2)

            enrichments = Security::FindingEnrichment.where(project: project)
            expect(enrichments.pluck(:cve)).to match_array(%w[CVE-2024-1234 CVE-2024-5678 CVE-2024-8910])
          end
        end

        context 'when CVE enrichment does not exist' do
          let_it_be(:security_finding_with_missing_cve) do
            build(:ci_reports_security_finding,
              identifiers: [build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-9999')])
          end

          let_it_be(:report_with_missing_cve) do
            build(
              :ci_reports_security_report,
              findings: [security_finding_with_missing_cve],
              scanner: security_scanner
            )
          end

          let(:service_object) do
            described_class.new(security_scan, scanner, report_with_missing_cve, [])
          end

          it 'creates finding enrichment records with empty cve_enrichment_id' do
            expect { store_findings }.to change(Security::FindingEnrichment, :count).by(1)

            finding_enrichment = Security::FindingEnrichment.last
            expect(finding_enrichment.cve_enrichment_id).to be_nil
            expect(finding_enrichment.epss_score).to be_nil
            expect(finding_enrichment.is_known_exploit).to be_nil
          end
        end

        context 'when enrichment population fails' do
          before do
            allow(Security::FindingEnrichment).to receive(:upsert_all).and_raise(StandardError.new('Database error'))
          end

          it 'tracks the exception' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              an_instance_of(StandardError),
              hash_including(
                security_scan_id: security_scan.id,
                project_id: project.id,
                class: 'Security::StoreFindingsService'
              )
            )

            store_findings
          end

          it 'still creates the security findings' do
            expect { store_findings }.to change(Security::Finding, :count).by(3)
          end
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(associate_security_findings_enrichment_records: false)
          end

          it 'creates the security finding entries in database' do
            expect { store_findings }.to change(Security::Finding, :count).by(3)
          end

          it 'does not create any finding enrichment records' do
            expect { store_findings }.not_to change(Security::FindingEnrichment, :count)
          end
        end
      end

      context 'when findings have no identifiers' do
        let_it_be(:security_finding_no_identifiers) do
          build(:ci_reports_security_finding, identifiers: [])
        end

        let_it_be(:report_no_identifiers) do
          build(
            :ci_reports_security_report,
            findings: [security_finding_no_identifiers],
            scanner: security_scanner
          )
        end

        let(:service_object) do
          described_class.new(security_scan, scanner, report_no_identifiers, [])
        end

        it 'does not create security finding entries for invalid findings' do
          expect { store_findings }.not_to change(Security::Finding, :count)
        end

        it 'does not create finding enrichment records' do
          expect { store_findings }.not_to change(Security::FindingEnrichment, :count)
        end
      end
    end
  end
end
