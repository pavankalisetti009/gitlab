# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestFindingIdentifiers, feature_category: :vulnerability_management do
  describe '#execute' do
    let(:pipeline) { create(:ci_pipeline) }
    let(:identifier) { create(:vulnerabilities_identifier) }
    let(:finding_1) { create(:vulnerabilities_finding) }
    let(:finding_2) { create(:vulnerabilities_finding) }
    let(:finding_map_1) { create(:finding_map, finding: finding_1, identifier_ids: [identifier.id]) }
    let(:finding_map_2) { create(:finding_map, finding: finding_2, identifier_ids: [identifier.id]) }
    let(:service_object) { described_class.new(pipeline, [finding_map_1, finding_map_2]) }

    subject(:ingest_finding_identifiers) { service_object.execute }

    before do
      Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
        %w[vulnerability_occurrence_identifiers], url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/480333'
      ) do
        ::Gitlab::Database.allow_cross_joins_across_databases(
          url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/480333'
        ) do
          finding_1.identifiers << identifier
        end
      end
    end

    it 'associates findings with the identifiers' do
      expect { ingest_finding_identifiers }.to change { Vulnerabilities::FindingIdentifier.count }.by(1)
                                           .and change {
                                                  finding_2.reload.identifiers.allow_cross_joins_across_databases(
                                                    url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/480333'
                                                  )
                                                }.from([]).to([identifier])
    end

    it_behaves_like 'bulk insertable task'
  end
end
