# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::BuildDependencyGraph, :unlimited_max_formatted_output_length, feature_category: :dependency_management do
  matcher :match_path do |ancestor, descendant, project_id, path_length, timestamp, top_level|
    match do |path|
      path.ancestor_id == ancestor \
        && path.descendant_id == descendant \
        && path.project_id == project_id \
        && path.path_length == path_length \
        && path.created_at == timestamp \
        && path.updated_at == timestamp \
        && path.top_level_ancestor == top_level
    end
  end

  describe "base test case" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:descendant) do
      create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
        input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:grandchild) do
      create(:sbom_occurrence,
        ancestors: [
          { name: descendant.component_name, version: descendant.version }
        ],
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

    let_it_be(:branch_parent) do
      create(:sbom_occurrence,
        ancestors: [
          { name: descendant.component_name, version: descendant.version },
          { name: grandchild.component_name, version: grandchild.version }
        ],
        input_file_path: descendant.input_file_path, project: project)
    end

    let(:expected_cache_key) { Sbom::LatestGraphTimestampCacheKey.new(project: project).cache_key }

    subject(:service) { described_class.new(project) }

    it "builds a dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, descendant.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, grandchild.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, branch_parent.id, project.id, 1, service.timestamp, true),
        match_path(grandchild.id, grandgrandchild.id, project.id, 1, service.timestamp, false),
        match_path(grandchild.id, branch_parent.id, project.id, 1, service.timestamp, false),
        match_path(grandgrandchild.id, deep_one.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, grandchild.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, branch_parent.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandgrandchild.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, branch_parent.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, deep_one.id, project.id, 4, service.timestamp, true),
        match_path(descendant.id, grandgrandchild.id, project.id, 2, service.timestamp, true),
        match_path(descendant.id, branch_parent.id, project.id, 2, service.timestamp, true),
        match_path(descendant.id, deep_one.id, project.id, 3, service.timestamp, true)
      )
    end

    it "sets the created_at timestamp of all new records to the same timestamp", :freeze_time do
      service.execute
      expect(Sbom::GraphPath.by_projects(project).pluck(:created_at)).to all eq(service.timestamp)
    end

    it "writes latest graph key to cache", :freeze_time do
      now = service.timestamp
      expect(Rails.cache).to receive(:write).with(expected_cache_key, now,
        expires_in: 24.hours).once
      service.execute
    end

    it "invokes the remove job after building the tree" do
      expect(Sbom::RemoveOldDependencyGraphsWorker).to receive(:perform_async).with(project.id)
      service.execute
    end

    it "does not store duplicate graph paths" do
      expect { service.execute }.to change {
        Sbom::GraphPath.by_projects(project).where(ancestor: descendant, descendant: grandchild).count
      }.from(0).to(1)
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 14,
        cache_hit: 0,
        cache_hit_rate: 0.0,
        cache_miss: 9,
        cache_miss_rate: 1
      )
      service.execute
    end
  end

  describe "base test case variant" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:descendant) do
      create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
        input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:descendant2) do
      create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
        input_file_path: ancestor.input_file_path, project: project)
    end

    let_it_be(:grandchild) do
      create(:sbom_occurrence,
        ancestors: [
          { name: descendant.component_name, version: descendant.version }
        ],
        input_file_path: descendant.input_file_path, project: project)
    end

    let_it_be(:grandchild2) do
      create(:sbom_occurrence, ancestors: [{ name: descendant.component_name, version: descendant.version }],
        input_file_path: descendant.input_file_path, project: project)
    end

    let_it_be(:grandchild3) do
      create(:sbom_occurrence, ancestors: [{ name: descendant2.component_name, version: descendant2.version }],
        input_file_path: descendant2.input_file_path, project: project)
    end

    let_it_be(:grandchild4) do
      create(:sbom_occurrence, ancestors: [{ name: descendant2.component_name, version: descendant2.version }],
        input_file_path: descendant2.input_file_path, project: project)
    end

    let_it_be(:deep_one) do
      create(:sbom_occurrence, ancestors: [{ name: grandchild4.component_name, version: grandchild4.version }],
        input_file_path: grandchild4.input_file_path, project: project)
    end

    let(:expected_cache_key) { Sbom::LatestGraphTimestampCacheKey.new(project: project).cache_key }

    subject(:service) { described_class.new(project) }

    it "builds a dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, descendant.id, project.id, 1, service.timestamp, true),
        match_path(ancestor.id, descendant2.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, grandchild.id, project.id, 1, service.timestamp, true),
        match_path(descendant.id, grandchild2.id, project.id, 1, service.timestamp, true),
        match_path(descendant2.id, grandchild3.id, project.id, 1, service.timestamp, true),
        match_path(descendant2.id, grandchild4.id, project.id, 1, service.timestamp, true),
        match_path(grandchild4.id, deep_one.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, grandchild.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandchild2.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandchild3.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, grandchild4.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, deep_one.id, project.id, 3, service.timestamp, true),
        match_path(descendant2.id, deep_one.id, project.id, 2, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 13,
        cache_hit: 0,
        cache_hit_rate: 0.0,
        cache_miss: 6,
        cache_miss_rate: 1.0
      )
      service.execute
    end
  end

  describe "cyclic paths" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:cycle_3_sbom_component) { create(:sbom_component) }
    let_it_be(:cycle_3_sbom_component_version) { create(:sbom_component_version, component: cycle_3_sbom_component) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:cycle_1) do
      create(:sbom_occurrence,
        ancestors: [
          { name: ancestor.component_name, version: ancestor.version },
          { name: cycle_3_sbom_component.name, version: cycle_3_sbom_component_version.version }
        ],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:cycle_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: cycle_1.component_name, version: cycle_1.version }],
        input_file_path: cycle_1.input_file_path,
        project: project
      )
    end

    let_it_be(:cycle_3) do
      create(:sbom_occurrence,
        component: cycle_3_sbom_component,
        component_version: cycle_3_sbom_component_version,
        ancestors: [{ name: cycle_2.component_name, version: cycle_2.version }],
        input_file_path: cycle_2.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf) do
      create(:sbom_occurrence,
        ancestors: [{ name: cycle_3.component_name, version: cycle_3.version }],
        input_file_path: cycle_3.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, cycle_1.id, project.id, 1, service.timestamp, true),
        match_path(cycle_1.id, cycle_2.id, project.id, 1, service.timestamp, false),
        match_path(cycle_2.id, cycle_3.id, project.id, 1, service.timestamp, false),
        match_path(cycle_3.id, cycle_1.id, project.id, 1, service.timestamp, false),
        match_path(cycle_3.id, leaf.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, cycle_2.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, cycle_3.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, leaf.id, project.id, 4, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 8,
        cache_hit: 0,
        cache_hit_rate: 0.0,
        cache_miss: 3,
        cache_miss_rate: 1.0
      )
      service.execute
    end
  end

  describe "early branch with a long left branch" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:child) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor.component_name, version: ancestor.version }],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:left_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:left_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: left_1.component_name, version: left_1.version }],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:left_3) do
      create(:sbom_occurrence,
        ancestors: [{ name: left_2.component_name, version: left_2.version }],
        input_file_path: left_2.input_file_path,
        project: project
      )
    end

    let_it_be(:right_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:union) do
      create(:sbom_occurrence,
        ancestors: [
          { name: left_3.component_name, version: left_3.version },
          { name: right_1.component_name, version: right_1.version }
        ],
        input_file_path: left_3.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, child.id, project.id, 1, service.timestamp, true),
        match_path(child.id, left_1.id, project.id, 1, service.timestamp, false),
        match_path(child.id, right_1.id, project.id, 1, service.timestamp, false),
        match_path(left_1.id, left_2.id, project.id, 1, service.timestamp, false),
        match_path(left_2.id, left_3.id, project.id, 1, service.timestamp, false),
        match_path(left_3.id, union.id, project.id, 1, service.timestamp, false),
        match_path(right_1.id, union.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_2.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, left_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, right_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, left_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, left_3.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 5, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 6, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 6, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 19,
        cache_hit: 4,
        cache_hit_rate: 0.3333333333333333,
        cache_miss: 8,
        cache_miss_rate: 0.6666666666666666
      )
      service.execute
    end
  end

  describe "early branch with a long right branch" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:child) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor.component_name, version: ancestor.version }],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:left_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:right_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:right_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: right_1.component_name, version: right_1.version }],
        input_file_path: right_1.input_file_path,
        project: project
      )
    end

    let_it_be(:right_3) do
      create(:sbom_occurrence,
        ancestors: [{ name: right_2.component_name, version: right_2.version }],
        input_file_path: right_2.input_file_path,
        project: project
      )
    end

    let_it_be(:union) do
      create(:sbom_occurrence,
        ancestors: [
          { name: left_1.component_name, version: left_1.version },
          { name: right_3.component_name, version: right_3.version }
        ],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, child.id, project.id, 1, service.timestamp, true),
        match_path(child.id, left_1.id, project.id, 1, service.timestamp, false),
        match_path(child.id, right_1.id, project.id, 1, service.timestamp, false),
        match_path(left_1.id, union.id, project.id, 1, service.timestamp, false),
        match_path(right_1.id, right_2.id, project.id, 1, service.timestamp, false),
        match_path(right_2.id, right_3.id, project.id, 1, service.timestamp, false),
        match_path(right_3.id, union.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_2.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, left_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, right_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, right_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, right_3.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 5, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 6, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 6, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 19,
        cache_hit: 4,
        cache_hit_rate: 0.3333333333333333,
        cache_miss: 8,
        cache_miss_rate: 0.6666666666666666
      )
      service.execute
    end
  end

  describe "equal length branches" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor) { create(:sbom_occurrence, project: project, ancestors: [{}]) }
    let_it_be(:child) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor.component_name, version: ancestor.version }],
        input_file_path: ancestor.input_file_path,
        project: project
      )
    end

    let_it_be(:left_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:left_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: left_1.component_name, version: left_1.version }],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:right_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child.component_name, version: child.version }],
        input_file_path: child.input_file_path,
        project: project
      )
    end

    let_it_be(:right_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: right_1.component_name, version: right_1.version }],
        input_file_path: right_1.input_file_path,
        project: project
      )
    end

    let_it_be(:union) do
      create(:sbom_occurrence,
        ancestors: [
          { name: left_2.component_name, version: left_2.version },
          { name: right_2.component_name, version: right_2.version }
        ],
        input_file_path: left_1.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: union.component_name, version: union.version }],
        input_file_path: union.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        match_path(ancestor.id, child.id, project.id, 1, service.timestamp, true),
        match_path(child.id, left_1.id, project.id, 1, service.timestamp, false),
        match_path(child.id, right_1.id, project.id, 1, service.timestamp, false),
        match_path(left_1.id, left_2.id, project.id, 1, service.timestamp, false),
        match_path(left_2.id, union.id, project.id, 1, service.timestamp, false),
        match_path(right_1.id, right_2.id, project.id, 1, service.timestamp, false),
        match_path(right_2.id, union.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(union.id, leaf_2.id, project.id, 1, service.timestamp, false),
        match_path(ancestor.id, left_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, right_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor.id, left_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, right_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor.id, union.id, project.id, 4, service.timestamp, true),
        match_path(ancestor.id, leaf_1.id, project.id, 5, service.timestamp, true),
        match_path(ancestor.id, leaf_2.id, project.id, 5, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 16,
        cache_hit: 2,
        cache_hit_rate: 0.2,
        cache_miss: 8,
        cache_miss_rate: 0.8
      )
      service.execute
    end
  end

  describe "'I' shape graph'" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:ancestor_left) do
      create(:sbom_occurrence, project: project, input_file_path: 'package.json', ancestors: [{}])
    end

    let_it_be(:ancestor_right) do
      create(:sbom_occurrence, project: project, input_file_path: 'package.json', ancestors: [{}])
    end

    let_it_be(:ancestor_middle) do
      create(:sbom_occurrence,
        project: project,
        ancestors: [
          { name: ancestor_left.component_name, version: ancestor_left.version },
          { name: ancestor_right.component_name, version: ancestor_right.version },
          {}
        ],
        input_file_path: ancestor_left.input_file_path
      )
    end

    let_it_be(:child_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: ancestor_middle.component_name, version: ancestor_middle.version }],
        input_file_path: ancestor_middle.input_file_path,
        project: project
      )
    end

    let_it_be(:child_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: child_1.component_name, version: child_1.version }],
        input_file_path: child_1.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_1) do
      create(:sbom_occurrence,
        ancestors: [{ name: child_2.component_name, version: child_2.version }],
        input_file_path: child_2.input_file_path,
        project: project
      )
    end

    let_it_be(:leaf_2) do
      create(:sbom_occurrence,
        ancestors: [{ name: child_2.component_name, version: child_2.version }],
        input_file_path: child_2.input_file_path,
        project: project
      )
    end

    subject(:service) { described_class.new(project) }

    it "builds expected dependency tree", :aggregate_failures, :freeze_time do
      service.execute
      resulting_paths = Sbom::GraphPath.by_projects(project)
      expect(resulting_paths).to contain_exactly(
        # All single paths
        match_path(ancestor_left.id, ancestor_middle.id, project.id, 1, service.timestamp, true),
        match_path(ancestor_right.id, ancestor_middle.id, project.id, 1, service.timestamp, true),
        match_path(ancestor_middle.id, child_1.id, project.id, 1, service.timestamp, true),
        match_path(child_1.id, child_2.id, project.id, 1, service.timestamp, false),
        match_path(child_2.id, leaf_1.id, project.id, 1, service.timestamp, false),
        match_path(child_2.id, leaf_2.id, project.id, 1, service.timestamp, false),
        # ancestor_left paths
        match_path(ancestor_left.id, child_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor_left.id, child_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor_left.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor_left.id, leaf_2.id, project.id, 4, service.timestamp, true),
        # ancestor_right paths
        match_path(ancestor_right.id, child_1.id, project.id, 2, service.timestamp, true),
        match_path(ancestor_right.id, child_2.id, project.id, 3, service.timestamp, true),
        match_path(ancestor_right.id, leaf_1.id, project.id, 4, service.timestamp, true),
        match_path(ancestor_right.id, leaf_2.id, project.id, 4, service.timestamp, true),
        # ancestor_middle paths
        match_path(ancestor_middle.id, child_2.id, project.id, 2, service.timestamp, true),
        match_path(ancestor_middle.id, leaf_1.id, project.id, 3, service.timestamp, true),
        match_path(ancestor_middle.id, leaf_2.id, project.id, 3, service.timestamp, true)
      )
    end

    it "logs the expected message when the build completes" do
      expect(::Gitlab::AppLogger).to receive(:info).with(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group.name,
        namespace_id: project.group.id,
        count_path_nodes: 17,
        cache_hit: 3,
        cache_hit_rate: 0.2727272727272727,
        cache_miss: 8,
        cache_miss_rate: 0.7272727272727273
      )
      service.execute
    end
  end
end
