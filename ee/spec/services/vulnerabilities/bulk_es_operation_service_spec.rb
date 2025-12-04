# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkEsOperationService, feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:vulnerabilities_set_1) { create_list(:vulnerability, 2, project: project) }

  before do
    allow(::Search::Elastic::VulnerabilityIndexHelper).to receive(:indexing_allowed?).and_return(true)

    allow_next_found_instance_of(Vulnerability) do |instance|
      allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
    end
  end

  it "avoids n+1 DB queries" do
    control = ActiveRecord::QueryRecorder.new do
      execute_service(vulnerabilities_set_1)
    end
    group_2 = create(:group, :nested)
    project_2 = create(:project, namespace: group_2)
    vulnerabilities_set_2 = create_list(:vulnerability, 2, project: project_2)

    expect do
      execute_service(vulnerabilities_set_1 + vulnerabilities_set_2)
    end.to issue_same_number_of_queries_as(control)
  end

  private

  def execute_service(vulnerabilities)
    relation = Vulnerability.id_in(vulnerabilities.map(&:id))
    described_class.new(relation).execute(&:itself)
  end
end
