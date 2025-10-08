# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::Vulnerabilities::PartnerTokenService, feature_category: :secret_detection do
  let_it_be(:project) { create(:project) }

  # Helpers for shared examples
  let(:expected_finding_type) { :vulnerability }
  let(:expected_token_status_model) { ::Vulnerabilities::FindingTokenStatus }
  let(:expected_unique_by_column) { :vulnerability_occurrence_id }

  let_it_be(:findings) { create_list(:vulnerabilities_finding, 3) }
  let_it_be(:finding) { create(:vulnerabilities_finding) }

  it_behaves_like 'partner token service'
end
