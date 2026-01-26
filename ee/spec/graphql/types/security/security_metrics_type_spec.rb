# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::SecurityMetricsType, feature_category: :vulnerability_management do
  let(:expected_fields) { %i[vulnerabilities_per_severity vulnerabilities_over_time risk_score vulnerabilities_by_age] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
