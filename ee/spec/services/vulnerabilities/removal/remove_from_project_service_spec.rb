# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Removal::RemoveFromProjectService, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:project_statistics) { project.statistics }
    let_it_be(:vulnerabilities) do
      create_list(
        :vulnerability,
        2,
        :with_finding,
        :with_state_transition,
        :with_notes,
        :with_issue_links,
        :with_user_mention,
        project: project)
    end

    let_it_be(:finding) { vulnerabilities.first.vulnerability_finding }

    let(:service_object) { described_class.new(project) }

    subject(:remove_vulnerabilities) { service_object.execute }

    describe 'batching' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)

        allow(Vulnerability).to receive(:transaction).and_call_original
      end

      it 'deletes records in batches' do
        remove_vulnerabilities

        expect(Vulnerability).to have_received(:transaction).twice
      end
    end

    describe 'deleting the records' do
      before do
        allow(Vulnerabilities::Statistics::AdjustmentWorker).to receive(:perform_async)
      end

      before_all do
        merge_request = create(:merge_request, source_project: project)

        create(:vulnerability_feedback, project: project)
        create(:vulnerability_statistic, project: project)
        create(:vulnerability_historical_statistic, project: project)

        create(:vulnerabilities_external_issue_link, vulnerability: vulnerabilities.first)
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerabilities.first, merge_request: merge_request)

        create(:finding_link, finding: finding)
        create(:vulnerabilities_flag, finding: finding)
        create(:vulnerabilties_finding_evidence, finding: finding)
        create(:vulnerabilities_finding_pipeline, finding: finding)
        create(:vulnerabilities_finding_signature, finding: finding)
        create(:vulnerabilities_finding_identifier, finding: finding)
        create(:vulnerabilities_remediation, project: project, findings: [finding])
      end

      it 'removes all the records from the database', :aggregate_failures do
        expect { remove_vulnerabilities }.to change { Vulnerability.count }.by(-2)
                                         .and change { Vulnerabilities::Read.count }.by(-2)
                                         .and change { Vulnerabilities::Flag.count }.by(-1)
                                         .and change { VulnerabilityUserMention.count }.by(-2)
                                         .and change { Vulnerabilities::Finding.count }.by(-2)
                                         .and change { Vulnerabilities::Feedback.count }.by(-1)
                                         .and change { Vulnerabilities::IssueLink.count }.by(-4)
                                         .and change { Vulnerabilities::Identifier.count }.by(-1)
                                         .and change { Vulnerabilities::FindingLink.count }.by(-1)
                                         .and change { Vulnerabilities::FindingPipeline.count }.by(-1)
                                         .and change { Vulnerabilities::StateTransition.count }.by(-2)
                                         .and change { Vulnerabilities::MergeRequestLink.count }.by(-1)
                                         .and change { Vulnerabilities::FindingSignature.count }.by(-1)
                                         .and change { Vulnerabilities::Finding::Evidence.count }.by(-1)
                                         .and change { Vulnerabilities::ExternalIssueLink.count }.by(-1)
                                         .and change { Vulnerabilities::FindingRemediation.count }.by(-1)
                                         .and change { Vulnerabilities::HistoricalStatistic.count }.by(-1)
                                         .and change { project_statistics.reload.vulnerability_count }.by(-2)

        expect(Vulnerabilities::Statistics::AdjustmentWorker).to have_received(:perform_async).with(project.id)
      end
    end
  end
end
