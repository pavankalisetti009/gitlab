# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['SquashOption'], feature_category: :source_code_management do
  subject { described_class }

  let(:fields) { %i[option help_text] }

  it { is_expected.to require_graphql_authorizations(:read_branch_rule) }

  it { is_expected.to have_graphql_fields(fields).at_least }
end
