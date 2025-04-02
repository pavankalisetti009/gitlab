# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.organization.workspaces_cluster_agents (filter: UNMAPPED)', feature_category: :workspaces do
  let(:filter) { :UNMAPPED }
  let(:expected_agents) { [unmapped_agent] }

  include_context "with agents and users setup in an organization"
  include_context "for a Query.organization.workspaces_cluster_agents query"

  it_behaves_like "multiple agents in organization query"
end
