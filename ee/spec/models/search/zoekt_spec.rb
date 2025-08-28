# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt, feature_category: :global_search do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be_with_reload(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group) }
  let_it_be_with_reload(:index) do
    create(:zoekt_index, :ready, zoekt_enabled_namespace: enabled_namespace, node: node)
  end

  let_it_be(:unassigned_group) { create(:group) }
  let_it_be_with_reload(:enabled_namespace_without_index) do
    create(:zoekt_enabled_namespace, namespace: unassigned_group)
  end

  describe '.search?' do
    before do
      stub_licensed_features(zoekt_code_search: true)
      stub_ee_application_setting(zoekt_search_enabled: true)
    end

    subject(:search) { described_class.search?(container) }

    [true, false].each do |search|
      context "when search on the zoekt_enabled_namespace is set to #{search}" do
        before do
          enabled_namespace.update!(search: search)
        end

        context 'when passed a project' do
          let(:container) { project }

          it { is_expected.to eq(search) }
        end
      end
    end

    context 'when no indices are ready' do
      let(:container) { project }

      before do
        index.update!(state: :initializing)
      end

      it { is_expected.to be(false) }
    end

    context 'when container is namespace' do
      let(:container) { group }

      context 'and there is no replica with ready state' do
        before do
          enabled_namespace.replicas.update_all(state: :pending)
        end

        it { is_expected.to be(false) }
      end

      context 'and there is at-least one replica with the ready state' do
        before do
          enabled_namespace.replicas.first.ready!
        end

        it { is_expected.to be(true) }

        context 'when zoekt_enabled_namespace search is false' do
          before do
            enabled_namespace.update!(search: false)
          end

          it { is_expected.to be(false) }
        end
      end
    end

    context 'when Zoekt::EnabledNamespace not found' do
      let(:container) { build(:project) }

      it { is_expected.to be(false) }
    end

    context 'when passed an unsupported class' do
      let(:container) { instance_double(Issue) }

      it { expect { search }.to raise_error(ArgumentError) }
    end
  end

  describe '.index?' do
    before do
      stub_licensed_features(zoekt_code_search: true)
      stub_ee_application_setting(zoekt_indexing_enabled: true)
    end

    subject(:index) { described_class.index?(container) }

    context 'when passed a project' do
      let(:container) { project }

      it { is_expected.to be(true) }
    end

    context 'when passed a namespace' do
      let(:container) { group }

      it { is_expected.to be(true) }
    end

    context 'when passed a root namespace id' do
      let(:container) { group.id }

      it { is_expected.to be(true) }
    end

    context 'when Zoekt::Index is not found' do
      let(:container) { build(:project) }

      it { is_expected.to be(false) }
    end

    context 'when passed an unsupported class' do
      let(:container) { instance_double(Issue) }

      it { expect { index }.to raise_error(ArgumentError) }
    end

    context 'when group is unassigned' do
      let(:container) { unassigned_group }

      it { is_expected.to be(false) }
    end
  end

  describe '.licensed_and_indexing_enabled?' do
    subject { described_class.licensed_and_indexing_enabled? }

    context 'when license feature zoekt_code_search is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when application setting zoekt_indexing_enabled is disabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when license feature zoekt_code_search and zoekt_indexing_enabled are enabled' do
      before do
        stub_licensed_features(zoekt_code_search: true)
        stub_ee_application_setting(zoekt_indexing_enabled: true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.enabled?' do
    subject { described_class.enabled? }

    context 'when license feature zoekt_code_search is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when application setting zoekt_search_enabled? is disabled' do
      before do
        stub_ee_application_setting(zoekt_search_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when license feature zoekt_code_search and application setting zoekt_search_enabled is enabled' do
      before do
        stub_licensed_features(zoekt_code_search: true)
        stub_ee_application_setting(zoekt_search_enabled: true)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.enabled_for_user?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:a_user) { create(:user) }

    subject(:enabled_for_user) { described_class.enabled_for_user?(user) }

    before do
      stub_ee_application_setting(zoekt_search_enabled: setting_zoekt_search_enabled)
      stub_licensed_features(zoekt_code_search: license_setting)

      allow(a_user).to receive(:enabled_zoekt?).and_return(user_setting)
    end

    where(:user, :setting_zoekt_search_enabled, :license_setting, :user_setting, :expected_result) do
      ref(:a_user) | true   | true  | true  | true
      ref(:a_user) | true   | true  | false | false
      ref(:a_user) | true   | false | true  | false
      ref(:a_user) | false  | true  | true  | false
      nil          | true   | true  | true  | true
    end

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end

  describe '.index_async' do
    subject(:index_async) { described_class.index_async(project.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(index_async).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      it 'calls IndexingTaskWorker async' do
        expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async).with(project.id, :index_repo)

        index_async
      end
    end
  end

  describe '.index_in' do
    subject(:index_in) { described_class.index_in(1.second, project.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(index_in).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      it 'calls IndexingTaskWorker async' do
        expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
          .with(project.id, :index_repo, { delay: 1.second })

        index_in
      end
    end
  end

  describe '.delete_async' do
    subject(:delete_async) { described_class.delete_async(project.id, root_namespace_id: group.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(delete_async).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      context 'when node_id is not provided' do
        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id })

          delete_async
        end
      end

      context 'when node_id is provided' do
        subject(:delete_async) do
          described_class.delete_async(project.id, root_namespace_id: group.id, node_id: node.id)
        end

        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id })

          delete_async
        end
      end
    end
  end

  describe '.delete_in' do
    subject(:delete_in) { described_class.delete_in(1.second, project.id, root_namespace_id: group.id) }

    context 'when licensed_and_indexing_enabled? returns false' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it 'does not call IndexingTaskWorker' do
        expect(Search::Zoekt::IndexingTaskWorker).not_to receive(:perform_async)

        expect(delete_in).to be false
      end
    end

    context 'when licensed_and_indexing_enabled? returns true' do
      before do
        allow(described_class).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      context 'when node_id is not provided' do
        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id, delay: 1.second })

          delete_in
        end
      end

      context 'when node_id is provided' do
        subject(:delete_in) do
          described_class.delete_in(2.seconds, project.id, root_namespace_id: group.id, node_id: node.id)
        end

        it 'calls IndexingTaskWorker async' do
          expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_async)
            .with(project.id, :delete_repo, { root_namespace_id: group.id, node_id: node.id, delay: 2.seconds })

          delete_in
        end
      end
    end
  end

  describe '.bin_path' do
    subject { described_class.bin_path }

    it { is_expected.to eq('tmp/tests/gitlab-zoekt/bin/gitlab-zoekt') }
  end

  describe '.traversal_id_searchable_for_global_search?' do
    let(:min_version) { described_class::MIN_SCHEMA_VERSION_FOR_TRAVERSAL_ID_SEARCH }

    before do
      Rails.cache.clear
    end

    it 'returns true when minimum_schema_version is greater than or equal to required minimum' do
      allow(::Search::Zoekt::Repository).to receive(:minimum_schema_version).and_return(min_version)
      expect(described_class.traversal_id_searchable_for_global_search?).to be true
    end

    it 'returns false when minimum_schema_version is less than required minimum' do
      allow(::Search::Zoekt::Repository).to receive(:minimum_schema_version).and_return(min_version - 1)
      expect(described_class.traversal_id_searchable_for_global_search?).to be false
    end

    it 'caches the result' do
      allow(::Search::Zoekt::Repository).to receive(:minimum_schema_version).and_return(min_version)
      expect(Rails.cache).to receive(:fetch).with('zoekt_traversal_id_searchable',
        expires_in: 10.minutes).and_call_original
      described_class.traversal_id_searchable_for_global_search?
    end
  end

  describe '.use_traversal_id_queries?' do
    using RSpec::Parameterized::TableSyntax
    let(:min_version) { described_class::MIN_SCHEMA_VERSION_FOR_TRAVERSAL_ID_SEARCH }
    let(:insufficient_version) { min_version - 1 }
    let(:a_user) { build(:user) }
    let(:scope) { ::Search::Zoekt::Repository }

    before do
      Rails.cache.clear
      allow(::Namespace).to receive(:find_by).with(id: group_id).and_return(group)
      allow(::Search::Zoekt::EnabledNamespace).to receive(:for_root_namespace_id)
        .with(group.root_ancestor.id).and_return([enabled_namespace])
      allow(::Search::Zoekt::Repository).to receive(:for_zoekt_indices).and_return(scope)
      allow(::Search::Zoekt::Repository).to receive(:for_project_id).with(project_id).and_return(scope)

      allow(scope).to receive(:minimum_schema_version).and_return(returned_min_version)
      stub_feature_flags(zoekt_traversal_id_queries: feature_enabled)
    end

    subject(:use_traversal_id_queries) do
      described_class.use_traversal_id_queries?(user, project_id: project_id, group_id: group_id)
    end

    where(:user, :feature_enabled, :project_id, :group_id, :returned_min_version, :expected_result) do
      # Feature disabled cases (should always be false)
      ref(:a_user)         | false  | 8675  | 309   | ref(:min_version)           | false
      ref(:a_user)         | false  | 8675  | 309   | ref(:insufficient_version)  | false
      ref(:a_user)         | false  | 8675  | nil   | ref(:min_version)           | false
      ref(:a_user)         | false  | nil   | 309   | ref(:min_version)           | false

      # Feature enabled cases
      # Project search
      ref(:a_user)         | true   | 8675  | nil   | ref(:min_version)           | true
      ref(:a_user)         | true   | 8675  | nil   | ref(:insufficient_version)  | false

      # Group search
      ref(:a_user)         | true   | nil   | 309   | ref(:min_version)           | true
      ref(:a_user)         | true   | nil   | 309   | ref(:insufficient_version)  | false

      # Global search
      ref(:a_user)         | true   | nil   | nil   | ref(:min_version)           | true
      ref(:a_user)         | true   | nil   | nil   | ref(:insufficient_version)  | false
    end

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end

  describe '.missing_repo?' do
    let(:repo_exists) { true }
    let(:empty_repo) { false }

    subject { described_class.missing_repo?(project) }

    before do
      allow(project).to receive_messages(repo_exists?: repo_exists, empty_repo?: empty_repo)
    end

    context 'when repository does not exist' do
      let(:repo_exists) { false }
      let(:empty_repo) { true }

      it { is_expected.to be true }
    end

    context 'when repository exists' do
      context 'and is empty' do
        let(:empty_repo) { true }

        it { is_expected.to be true }
      end

      context 'and is not empty' do
        it { is_expected.to be false }
      end
    end
  end
end
