# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Removal::RemoveFromProjectService, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
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
        merge_request = create(:merge_request, source_project: project)

        create(:vulnerabilities_merge_request_link, vulnerability: vulnerabilities.first, merge_request: merge_request)
        create(:vulnerability_statistic, project: project)
        create(:vulnerability_historical_statistic, project: project)
        create(:vulnerability_feedback, project: project)
        create(:vulnerabilities_external_issue_link, vulnerability: vulnerabilities.first)
        create(:finding_link, finding: vulnerabilities.first.finding)
        create(:vulnerabilities_finding_pipeline, finding: vulnerabilities.first.finding)
      end

      it 'removes all the records from the database', :aggregate_failures do
        # Number for the finding model is off because of a bug introduced by
        # https://gitlab.com/gitlab-org/gitlab/-/commit/34772c2ca6742c08b059bb93b9367d3a8c195695
        expect { remove_vulnerabilities }.to change { Vulnerability.count }.by(-2)
                                         .and change { Vulnerabilities::Read.count }.by(-2)
                                         .and change { Vulnerabilities::Finding.count }.by(-4)
                                         .and change { Vulnerabilities::Scanner.count }.by(-4)
                                         .and change { Vulnerabilities::Identifier.count }.by(-6)
                                         .and change { Vulnerabilities::IssueLink.count }.by(-4)
                                         .and change { Vulnerabilities::StateTransition.count }.by(-2)
                                         .and change { VulnerabilityUserMention.count }.by(-2)
                                         .and change { Vulnerabilities::MergeRequestLink.count }.by(-1)
                                         .and change { Vulnerabilities::Statistic.count }.by(-1)
                                         .and change { Vulnerabilities::HistoricalStatistic.count }.by(-1)
                                         .and change { Vulnerabilities::ExternalIssueLink.count }.by(-1)
                                         .and change { Vulnerabilities::FindingLink.count }.by(-1)
                                         .and change { Vulnerabilities::FindingPipeline.count }.by(-1)
                                         .and change { Vulnerabilities::Feedback.count }.by(-1)
      end
    end
  end
end
