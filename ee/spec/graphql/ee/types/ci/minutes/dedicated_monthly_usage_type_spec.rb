# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiDedicatedHostedRunnerUsage'], feature_category: :hosted_runners do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[billing_month billing_month_iso8601 compute_minutes duration_seconds root_namespace] }

  it { is_expected.to have_graphql_fields(fields) }
end
