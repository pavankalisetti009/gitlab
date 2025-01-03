# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::UpdateProjectRunnersOwnerService, '#execute', feature_category: :runner do
  let_it_be(:owner_group) { create(:group) }
  let_it_be(:owner_project) { create(:project, group: owner_group) }
  let_it_be(:new_project) { create(:project) }

  let(:service) { described_class.new(owner_project.id) }
  let!(:owned_runner1) { create(:ci_runner, :project, projects: [owner_project, new_project]) }
  let!(:owned_runner2) { create(:ci_runner, :project, projects: [owner_project]) }
  let!(:other_runner) { create(:ci_runner, :project, projects: [new_project]) }
  let!(:orphaned_runner) { create(:ci_runner, :project, :without_projects) }

  subject(:execute) { service.execute }

  before do
    owner_project.destroy!
  end

  it 'updates sharding_key_id on affected runners', :aggregate_failures do
    expect_next_instance_of(Ci::Runners::UnregisterRunnerService, owned_runner2, owned_runner2.token) do |service|
      expect(service).to receive(:execute).and_call_original
    end

    expect { execute }
      .to change { owned_runner1.reload.sharding_key_id }.from(owner_project.id).to(new_project.id)
      .and change { Ci::Runner.find_by_id(owned_runner2) }.to(nil) # delete, since no other project to adopt it
      .and not_change { other_runner.reload.sharding_key_id }.from(new_project.id) # runner's project is not affected
      .and not_change { orphaned_runner.reload.sharding_key_id }

    expect(execute).to be_success
  end
end
