# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyScope'], feature_category: :security_policy_management do
  let(:fields) do
    %i[compliance_frameworks including_projects excluding_personal_projects excluding_projects including_groups
      excluding_groups]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
