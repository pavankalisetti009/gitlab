# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::BuildDependencyGraph, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:ancestor) { create(:sbom_occurrence, project: project) }
  let_it_be(:descendant) do
    create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
      input_file_path: ancestor.input_file_path, project: project)
  end

  let_it_be(:grandchild) do
    create(:sbom_occurrence, ancestors: [{ name: descendant.component_name, version: descendant.version }],
      input_file_path: descendant.input_file_path, project: project)
  end

  let_it_be(:grandgrandchild) do
    create(:sbom_occurrence, ancestors: [{ name: grandchild.component_name, version: grandchild.version }],
      input_file_path: grandchild.input_file_path, project: project)
  end

  let_it_be(:deep_one) do
    create(:sbom_occurrence, ancestors: [{ name: grandgrandchild.component_name, version: grandgrandchild.version },
      {}], input_file_path: grandgrandchild.input_file_path, project: project)
  end

  let(:connection) { SecApplicationRecord.connection }

  subject(:service) { described_class.new(project) }

  it "builds a dependency tree", :aggregate_failures do
    expect { service.execute }.to change { Sbom::GraphPath.by_projects(project).count }.from(0)
  end

  it 'acquires an advisory lock' do
    lock_key = ["build-dependency-graph-for-project_id", Integer(project.id)].join("-")

    expect(Sbom::GraphPath).to receive(:connection).twice.and_return(connection)
    expect(connection).to receive(:quote).with(lock_key).and_call_original
    expect(connection).to receive(:execute).with(/SELECT pg_try_advisory_xact_lock/).and_call_original

    result = service.send(:use_advisory_lock)
    expect(result).to be_truthy
  end

  it 'raises when advisory lock cannot be acquired' do
    expect(service).to receive(:use_advisory_lock).and_return(false)

    expect { service.execute }.to raise_error(Sbom::BuildDependencyGraph::CouldNotAcquireAdvisoryLock)
  end

  context "when a dependency tree already exists" do
    before do
      create(:sbom_graph_path, project: project)
    end

    it "clears existing paths" do
      expect { service.execute }.to change { Sbom::GraphPath.count }.from(1).to(6)
    end
  end
end
