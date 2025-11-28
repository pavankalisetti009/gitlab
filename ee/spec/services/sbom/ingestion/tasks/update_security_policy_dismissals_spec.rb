# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::UpdateSecurityPolicyDismissals, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, sha: 'test_sha') }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, merge_commit_sha: pipeline.sha) }

  let(:occurrence_maps) { create_list(:sbom_occurrence_map, 2, :for_occurrence_ingestion, vulnerabilities: nil) }
  let(:licenses_fetcher) { instance_double(Sbom::Ingestion::LicensesFetcher) }

  subject(:update_security_policy_dismissals) { described_class.new(pipeline, occurrence_maps).execute }

  before do
    allow(Sbom::Ingestion::LicensesFetcher).to receive(:new).and_return(licenses_fetcher)
  end

  describe '#execute' do
    context 'when there are no policy dismissals' do
      it 'returns early' do
        expect(Sbom::Ingestion::LicensesFetcher).not_to receive(:new)

        update_security_policy_dismissals
      end
    end

    context 'when there are policy dismissals' do
      let_it_be(:mit_license) { 'MIT License' }
      let_it_be(:apache_license) { 'Apache License 2.0' }
      let_it_be(:gpl_license) { 'GPL-3-Clause' }

      let_it_be(:component_1) { 'rack' }
      let_it_be(:component_2) { 'aws-sdk-s3' }

      let_it_be(:policy_dismissal_1) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          licenses: { mit_license => [component_1] })
      end

      let_it_be(:policy_dismissal_2) do
        create(:policy_dismissal,
          project: project,
          merge_request: merge_request,
          licenses: { apache_license => [component_2] })
      end

      let(:occurrence_map_1_uuid) { SecureRandom.uuid }
      let(:occurrence_map_1) do
        create(:sbom_occurrence_map, report_component: create(:ci_reports_sbom_component, name: component_1))
      end

      let(:occurrence_map_2_uuid) { SecureRandom.uuid }
      let(:occurrence_map_2) do
        create(:sbom_occurrence_map, report_component: create(:ci_reports_sbom_component, name: component_2))
      end

      let(:occurrence_map_3_uuid) { SecureRandom.uuid }
      let(:occurrence_map_3) do
        create(:sbom_occurrence_map, report_component: create(:ci_reports_sbom_component, name: 'component-c'))
      end

      let(:occurrence_maps) { [occurrence_map_1, occurrence_map_2, occurrence_map_3] }

      before do
        occurrence_map_1.uuid = occurrence_map_1_uuid
        occurrence_map_2.uuid = occurrence_map_2_uuid
        occurrence_map_3.uuid = occurrence_map_3_uuid

        allow(licenses_fetcher).to receive(:fetch).with(occurrence_map_1.report_component).and_return(
          [Hashie::Mash.new({ name: mit_license })]
        )
        allow(licenses_fetcher).to receive(:fetch).with(occurrence_map_2.report_component).and_return(
          [Hashie::Mash.new({ name: apache_license })]
        )
        allow(licenses_fetcher).to receive(:fetch).with(occurrence_map_3.report_component).and_return(
          [Hashie::Mash.new({ name: gpl_license })]
        )
      end

      it 'updates the license_occurrence_uuids for matching policy dismissals' do
        expect do
          update_security_policy_dismissals

          policy_dismissal_1.reload
          policy_dismissal_2.reload
        end.to change { policy_dismissal_1.license_occurrence_uuids }.from([]).to([occurrence_map_1_uuid])
          .and change { policy_dismissal_2.license_occurrence_uuids }.from([]).to([occurrence_map_2_uuid])
      end

      context 'when a component has multiple licenses' do
        let(:policy_dismissal) do
          create(:policy_dismissal,
            project: project,
            merge_request: merge_request,
            licenses: { mit_license => [component_1] })
        end

        before do
          allow(licenses_fetcher).to receive(:fetch).with(occurrence_map_1.report_component).and_return(
            [Hashie::Mash.new({ name: mit_license }),
              Hashie::Mash.new({ name: 'GPL-3.0' })]
          )
        end

        it 'updates the policy dismissal if any license matches' do
          expect do
            update_security_policy_dismissals

            policy_dismissal.reload
          end.to change { policy_dismissal.license_occurrence_uuids }.from([]).to([occurrence_map_1_uuid])
        end
      end

      context 'when a policy dismissal has multiple components for a license' do
        let_it_be(:policy_dismissal) do
          create(:policy_dismissal,
            project: project,
            merge_request: merge_request,
            licenses: { mit_license => [component_1, 'component-x'] })
        end

        it 'updates the policy dismissal if any component matches' do
          expect do
            update_security_policy_dismissals

            policy_dismissal.reload
          end.to change { policy_dismissal.license_occurrence_uuids }.from([]).to([occurrence_map_1_uuid])
        end
      end

      context 'when a license name is nil' do
        let(:policy_dismissal) do
          create(:policy_dismissal,
            project: project,
            merge_request: merge_request,
            licenses: { mit_license => [component_1] })
        end

        let(:occurrence_map_1) do
          create(:sbom_occurrence_map, report_component: create(:ci_reports_sbom_component, name: component_1))
        end

        before do
          allow(licenses_fetcher).to receive(:fetch).with(occurrence_map_1.report_component).and_return(
            [Hashie::Mash.new({ name: nil })]
          )
        end

        it 'does not update the policy dismissal' do
          expect do
            update_security_policy_dismissals

            policy_dismissal.reload
          end.not_to change { policy_dismissal.license_occurrence_uuids }
        end
      end

      context 'when the feature flag `security_policy_warn_mode_license_scanning` is disabled' do
        before do
          stub_feature_flags(security_policy_warn_mode_license_scanning: false)
        end

        it 'returns early' do
          expect(MergeRequest).not_to receive(:by_merge_request_sha)

          update_security_policy_dismissals
        end
      end
    end
  end
end
