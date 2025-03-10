# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::VulnerabilitiesType, feature_category: :vulnerability_management do
  let(:fields) do
    %i[type related_vulnerabilities]
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetVulnerabilities') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end
