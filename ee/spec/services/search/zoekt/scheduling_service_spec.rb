# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SchedulingService, :clean_gitlab_redis_shared_state, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(task.to_s) }
  let_it_be_with_reload(:node) { create(:zoekt_node, :enough_free_space) }

  subject(:execute_task) { service.execute }

  before do
    allow(described_class).to receive(:logger).and_return(logger)
  end

  shared_examples 'a execute_every task' do
    it 'uses cache', :clean_gitlab_redis_shared_state do
      expect(Gitlab::Redis::SharedState).to receive(:with)
      service.execute
    end

    context 'when on development environment', :clean_gitlab_redis_shared_state do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'does not use cache' do
        expect(Gitlab::Redis::SharedState).not_to receive(:with)
      end
    end
  end

  describe '.execute' do
    let(:task) { :foo }

    it 'executes the task' do
      expect(described_class).to receive(:new).with(task).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(task)
    end

    context 'when passed without_cache argument' do
      let(:redis) { instance_double(Redis) }

      it 'removes the cache key before executing the task' do
        expect(Gitlab::Redis::SharedState).to receive(:with).and_yield(redis)
        expect(redis).to receive(:del).with(service.cache_key)

        expect(described_class).to receive(:new).with(task).and_return(service)
        expect(service).to receive(:execute)

        described_class.execute(task, without_cache: true)
      end
    end
  end

  describe '.execute!' do
    let(:task) { :foo }

    it 'calls .execute specifying without_cache' do
      expect(described_class).to receive(:execute).with(task, without_cache: true)

      described_class.execute!(task)
    end
  end

  describe '#execute' do
    let(:task) { :foo }

    it 'raises an exception when unknown task is provided' do
      expect { service.execute }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::Zoekt::SchedulingService::TASKS', [:foo])

      expect { service.execute }.to raise_error(NotImplementedError)
    end

    it 'converts string task to symbol' do
      expect(described_class.new(task.to_s).task).to eq(task.to_sym)
    end
  end

  describe '#cache_key' do
    it 'is formatted correctly based on task name' do
      %i[foo bar baz].each do |task|
        expect(described_class.new(task).cache_key).to eq("search/zoekt/scheduling_service:execute_every:#{task}")
      end
    end
  end

  describe '#eviction' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :eviction }

    before do
      allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
    end

    it 'returns false unless saas' do
      expect(execute_task).to be(false)
    end

    context 'when on .com', :saas do
      let_it_be(:zoekt_index) { create(:zoekt_index, node: node) }

      context 'when nodes have enough storage' do
        it 'returns false' do
          expect(logger).not_to receive(:info)
          expect { execute_task }.not_to change { Search::Zoekt::Replica.count }
        end
      end

      context 'when nodes are over the watermark high limit' do
        let_it_be(:node_out_of_storage) { create(:zoekt_node, :not_enough_free_space) }
        let_it_be(:namespace_statistics) do
          create(:namespace_root_storage_statistics, repository_size: node_out_of_storage.used_bytes * 0.7)
        end

        let_it_be(:ns) { create(:group, root_storage_statistics: namespace_statistics) }
        let_it_be(:enabled_ns) { create(:zoekt_enabled_namespace, namespace: ns) }
        let_it_be(:zoekt_index2) do
          create(:zoekt_index, node: node_out_of_storage, zoekt_enabled_namespace: enabled_ns)
        end

        it 'removes extra indices and logs' do
          expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
            'message' => 'Detected nodes over watermark',
            'watermark_limit_high' => ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            'count' => 1 }
          )

          expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
            'message' => 'Unassigning namespaces from node',
            'watermark_limit_high' => ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            'count' => 1,
            'node_used_bytes' => 90000000,
            'node_expected_used_bytes' => 27000001,
            'total_repository_size' => namespace_statistics.repository_size,
            'meta' => node_out_of_storage.metadata_json.merge(
              'zoekt.used_bytes' => 27000001, 'zoekt.storage_percent_used' => 0.27000001) }
          )

          expect { execute_task }.to change { Search::Zoekt::Replica.count }.from(2).to(1)
        end

        it 'keeps search enabled for the enabled namespace' do
          allow(logger).to receive(:info)
          expect { execute_task }.not_to change { zoekt_index2.zoekt_enabled_namespace.reload.search }
        end
      end

      it_behaves_like 'a execute_every task'
    end
  end

  describe '#dot_com_rollout' do
    let(:task) { :dot_com_rollout }

    it 'returns false unless saas' do
      expect(execute_task).to be(false)
    end

    context 'when on .com', :saas do
      let_it_be(:group) { create(:group) }
      let_it_be(:subscription) { create(:gitlab_subscription, namespace: group) }
      let_it_be(:root_storage_statistics) { create(:namespace_root_storage_statistics, namespace: group) }

      it_behaves_like 'a execute_every task'

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(zoekt_dot_com_rollout: false)
        end

        it 'returns false' do
          create(:zoekt_enabled_namespace)

          expect(execute_task).to be(false)
        end
      end

      it 'creates an enabled namespace for namespaces with active subscriptions' do
        another_group = create(:group)
        create(:gitlab_subscription, namespace: another_group, end_date: 2.weeks.ago)
        create(:namespace_root_storage_statistics, namespace: another_group)

        expect { execute_task }.to change { ::Search::Zoekt::EnabledNamespace.count }.by(1)

        expect(::Search::Zoekt::EnabledNamespace.pluck(:root_namespace_id)).to contain_exactly(group.id)
      end
    end
  end

  describe '#remove_expired_subscriptions' do
    let(:task) { :remove_expired_subscriptions }

    it 'returns false unless saas' do
      expect(execute_task).to be(false)
    end

    context 'when on .com', :saas do
      let_it_be(:expiration_date) { Time.zone.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD }
      let_it_be(:zkt_enabled_namespace) { create(:zoekt_enabled_namespace) }
      let_it_be(:zkt_enabled_namespace2) { create(:zoekt_enabled_namespace) }
      let_it_be(:subscription) { create(:gitlab_subscription, namespace: zkt_enabled_namespace2.namespace) }
      let_it_be(:expired_subscription) do
        create(:gitlab_subscription, namespace: zkt_enabled_namespace.namespace, end_date: expiration_date - 1.day)
      end

      it 'destroys zoekt_namespaces with expired subscriptions' do
        expect { execute_task }.to change { ::Search::Zoekt::EnabledNamespace.count }.by(-1)

        expect(::Search::Zoekt::EnabledNamespace.pluck(:id)).to contain_exactly(zkt_enabled_namespace2.id)
      end
    end
  end

  describe '#node_assignment' do
    let(:task) { :node_assignment }

    let_it_be(:namespace) { create(:group) }
    let_it_be_with_reload(:namespace_statistics) { create(:namespace_root_storage_statistics, repository_size: 1000) }
    let_it_be_with_reload(:namespace_with_statistics) do
      create(:group, :with_hierarchy, root_storage_statistics: namespace_statistics, children: 1, depth: 3)
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_node_assignment: false)
      end

      it 'returns false' do
        expect(execute_task).to be(false)
      end
    end

    context 'when some zoekt enabled namespaces missing zoekt index' do
      let(:logger) { instance_double(::Search::Zoekt::Logger) }
      let_it_be(:zkt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace.root_ancestor) }
      let_it_be(:zkt_enabled_namespace2) do
        create(:zoekt_enabled_namespace, namespace: namespace_with_statistics.root_ancestor)
      end

      let_it_be(:zoekt_replica) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: zkt_enabled_namespace2) }

      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      end

      context 'when there are no online nodes' do
        before do
          allow(Search::Zoekt::Node).to receive(:online).and_return(Search::Zoekt::Node.none)
        end

        it 'returns false and does nothing' do
          expect(execute_task).to be(false)
          expect(Search::Zoekt::EnabledNamespace).not_to receive(:with_missing_indices)
        end
      end

      context 'when there is not enough space in any nodes' do
        before do
          node.update_column(:total_bytes, 100)
        end

        it 'does not creates a record of Search::Zoekt::Index for the namespace' do
          node_free_space = node.total_bytes - node.used_bytes
          expect(namespace_statistics.repository_size).to be > node_free_space
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
          expect(Search::Zoekt::Node).to receive(:online).and_call_original
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                          'message' => "RootStorageStatistics isn't available",
                                                          'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
          )
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                          'message' => 'Namespace is too big even for multiple indices',
                                                          'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id })
          expect { execute_task }.not_to change { Search::Zoekt::Index.count }
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
        end

        context 'when there is space for the repository but not for the WATERMARK_LIMIT_LOW' do
          before do
            node.update_column(:total_bytes,
              (namespace_statistics.repository_size * described_class::BUFFER_FACTOR) + node.used_bytes)
          end

          it 'does not creates a record of Search::Zoekt::Index for the namespace' do
            node_free_space = node.total_bytes - node.used_bytes
            # Assert that node's free space is equal to the repository_size times BUFFER_FACTOR
            expect(namespace_statistics.repository_size * described_class::BUFFER_FACTOR).to eq node_free_space
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
            expect(Search::Zoekt::Node).to receive(:online).and_call_original
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                    'message' => "RootStorageStatistics isn't available",
                                                    'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                    'message' => 'Namespace is too big even for multiple indices',
                                                    'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id }
            )
            expect { execute_task }.not_to change { Search::Zoekt::Index.count }
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
          end
        end
      end

      context 'when there is enough space in the node' do
        context 'when a new record of Search::Zoekt::Index could not be saved' do
          it 'logs error' do
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
            expect(Search::Zoekt::Node).to receive(:online).and_call_original
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                    'message' => "RootStorageStatistics isn't available",
                                                    'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            allow_next_instance_of(Search::Zoekt::Index) do |instance|
              allow(instance).to receive(:valid?).and_return(false)
            end
            expect(logger).to receive(:error).with(hash_including('zoekt_index', 'class' => described_class.to_s,
              'task' => task, 'message' => 'Could not save Search::Zoekt::Index'))
            expect { execute_task }.not_to change { Search::Zoekt::Index.count }
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
          end
        end

        it 'creates a record of Search::Zoekt::Index with state pending for the namespace which has statistics' do
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
          expect(Search::Zoekt::Node).to receive(:online).and_call_original
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                  'message' => "RootStorageStatistics isn't available",
                                                  'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
          )
          expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
          expect(zkt_enabled_namespace.indices).to be_empty
          index = zkt_enabled_namespace2.indices.last
          expect(index).not_to be_nil
          expect(index.namespace_id).to eq zkt_enabled_namespace2.root_namespace_id
          expect(index.reserved_storage_bytes).not_to be_nil
          expect(index).to be_pending
        end

        context 'when storage_size for a namespace is 0' do
          before do
            namespace_statistics.update_column(:repository_size, 0)
          end

          it 'creates a record of Search::Zoekt::Index with state ready for the namespace which has statistics' do
            expect(zkt_enabled_namespace.indices).to be_empty
            expect(zkt_enabled_namespace2.indices).to be_empty
            expect(Search::Zoekt::Node).to receive(:online).and_call_original
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
            expect(zkt_enabled_namespace.indices).to be_empty
            index = zkt_enabled_namespace2.indices.last
            expect(index).not_to be_nil
            expect(index.namespace_id).to eq zkt_enabled_namespace2.root_namespace_id
            expect(index.reserved_storage_bytes).not_to be_nil
            expect(index).to be_ready
          end
        end

        it 'assigns the index to a replica' do
          expect(zkt_enabled_namespace.indices).to be_empty
          expect(zkt_enabled_namespace2.indices).to be_empty
          expect(Search::Zoekt::Node).to receive(:online).and_call_original
          expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                  'message' => "RootStorageStatistics isn't available",
                                                  'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
          )
          expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
          expect(zkt_enabled_namespace.indices).to be_empty
          execute_task

          index = zkt_enabled_namespace2.indices.last
          expect(index.replica).to be_present
        end
      end

      context 'for a big namespace when it can not be accommodated in a single node' do
        let_it_be(:project) { create(:project, :repository, namespace: namespace_with_statistics) }
        let_it_be(:project2) { create(:project, :repository, namespace: namespace_with_statistics.children.first) }
        let_it_be_with_reload(:project_stat1) { create(:project_statistics, project: project, with_data: true) }
        let_it_be_with_reload(:project_stat2) do
          create(:project_statistics, project: project2, with_data: true, size_multiplier: 18)
        end

        before do
          node.update_column(:total_bytes, 100)
        end

        context 'when all projects repository_size is 0' do
          before do
            ProjectStatistics.where(id: [project_stat1.id, project_stat2.id]).update_all(repository_size: 0)
          end

          it 'creates single index in ready state' do
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )
            expect { execute_task }.to change { Search::Zoekt::Index.count }.by(1)
            indices = zkt_enabled_namespace2.indices
            expect(indices.count).to eq 1
            expect(indices.first.metadata['project_id_from']).to eq namespace_with_statistics.all_projects.first.id
            expect(indices.first).to be_ready
          end
        end

        context 'when a namespace can be accommodated within 5 nodes' do
          before do
            create_list(:zoekt_node, 4)
          end

          it 'creates multiple indices in pending state' do
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )

            expect { execute_task }.to change { Search::Zoekt::Index.count }.by(2)
            indices = zkt_enabled_namespace2.indices
            expect(indices.count).to eq 2
            expect(indices.first.metadata['project_id_from']).to eq namespace_with_statistics.all_projects.first.id
            expect(indices.first.metadata['project_id_to']).to eq namespace_with_statistics.all_projects.first.id
            expect(indices.last.metadata['project_id_from']).to eq namespace_with_statistics.all_projects.last.id
            expect(indices.first).to be_pending
            expect(indices.last).to be_pending
          end
        end

        context 'when a namespace can not be accommodated within 5 nodes' do
          before do
            project_stat1.update_column(:repository_size, 100)
            project_stat2.update_column(:repository_size, 100)
          end

          it 'does not create any indices and log error' do
            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => "RootStorageStatistics isn't available",
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace.id }
            )

            expect(logger).to receive(:error).with({ 'class' => described_class.to_s, 'task' => task,
                                                     'message' => 'Namespace is too big even for multiple indices',
                                                     'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id }
            )
            expect { execute_task }.not_to change { Search::Zoekt::Index.count }
          end
        end
      end
    end
  end

  describe '#mark_indices_as_ready' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :mark_indices_as_ready }
    let_it_be(:idx) { create(:zoekt_index, state: :initializing) }
    let_it_be(:idx2) { create(:zoekt_index, state: :initializing) }
    let_it_be(:idx3) { create(:zoekt_index, state: :initializing) }
    let_it_be(:idx4) { create(:zoekt_index) }
    let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
    let_it_be(:idx_project2) { create(:project, namespace_id: idx.namespace_id) }
    let_it_be(:idx2_project2) { create(:project, namespace_id: idx2.namespace_id) }
    let_it_be(:idx4_project) { create(:project, namespace_id: idx4.namespace_id) }

    before do
      allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :pending)
      idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project2, state: :ready)
      idx2.zoekt_repositories.create!(zoekt_index: idx2, project: idx2_project2, state: :ready)
      idx4.zoekt_repositories.create!(zoekt_index: idx4, project: idx4_project, state: :ready)
    end

    # idx has some pending zoekt_repositories
    # idx2 has all ready zoekt_repositories
    # idx3 does not have zoekt_repositories
    # idx4 all ready zoekt_repositories but zoekt_index is pending
    it 'moves initializing indices to ready that do not have any zoekt_repos or all finished zoekt_repos' do
      expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task, 'count' => 2,
                                              'message' => 'Set indices ready' }
      )
      execute_task
      expect([idx, idx2, idx3, idx4].map { |i| i.reload.state }).to eq(%w[initializing ready ready pending])
    end
  end

  describe '#initial_indexing' do
    let(:task) { :initial_indexing }
    let_it_be_with_reload(:index) { create(:zoekt_index, state: :pending) }

    context 'when there are no zoekt_indices in pending state' do
      before do
        Search::Zoekt::Index.update_all(state: :initializing)
      end

      it 'does not publish the event Search::Zoekt::InitialIndexingEvent' do
        expect { execute_task }.not_to publish_event(Search::Zoekt::InitialIndexingEvent)
      end
    end

    it 'publishes the event Search::Zoekt::InitialIndexingEvent for the pending indices' do
      expect { execute_task }.to publish_event(Search::Zoekt::InitialIndexingEvent).with({ index_id: index.id })
    end
  end

  describe '#auto_index_self_managed' do
    let(:task) { :auto_index_self_managed }
    let_it_be(:sub_group) { create(:group, :nested) }
    let_it_be(:top_group) { create(:group) }
    let_it_be(:top_group2) { create(:group) }

    before do
      stub_ee_application_setting(zoekt_auto_index_root_namespace: true)
      create(:zoekt_enabled_namespace, root_namespace_id: top_group2.id)
    end

    context 'for gitlab.com', :saas do
      it 'does not create any record of Search::Zoekt::EnabledNamespace' do
        expect { execute_task }.not_to change { Search::Zoekt::EnabledNamespace.count }
      end
    end

    context 'when application setting zoekt_auto_index_root_namespace is false' do
      before do
        stub_ee_application_setting(zoekt_auto_index_root_namespace: false)
      end

      it 'does not create any record of Search::Zoekt::EnabledNamespace' do
        expect { execute_task }.not_to change { Search::Zoekt::EnabledNamespace.count }
      end
    end

    it "creates zoekt_enabled_namespace for the root groups that don't have zoekt_enabled_namespace already" do
      expect(sub_group.root_ancestor.zoekt_enabled_namespace).to be_nil
      expect(top_group.zoekt_enabled_namespace).to be_nil
      expect(top_group2.zoekt_enabled_namespace).not_to be_nil
      expect { execute_task }.to change { Search::Zoekt::EnabledNamespace.count }.by(2)
      expect(sub_group.root_ancestor.reload.zoekt_enabled_namespace).not_to be_nil
      expect(top_group.reload.zoekt_enabled_namespace).not_to be_nil
    end
  end

  describe '#update_replica_states' do
    let(:task) { :update_replica_states }

    it 'calls ReplicaStateService.execute' do
      expect(::Search::Zoekt::ReplicaStateService).to receive(:execute)
      execute_task
    end

    context 'when zoekt replica state updates FF is disabled' do
      before do
        stub_feature_flags(zoekt_replica_state_updates: false)
      end

      it 'returns false and does not do anything' do
        expect(::Search::Zoekt::ReplicaStateService).not_to receive(:execute)
        expect(execute_task).to be(false)
      end
    end
  end

  describe '#update_index_used_bytes' do
    let(:task) { :update_index_used_bytes }
    let_it_be(:index) { create(:zoekt_index, :ready) }
    let_it_be(:repo) { create(:zoekt_repository, zoekt_index: index) }
    let_it_be(:another_repo) { create(:zoekt_repository, zoekt_index: index) }

    it 'resizes ready indices used_storage_bytes' do
      expect do
        execute_task
      end.to change {
        index.reload.used_storage_bytes
      }.from(0).to(repo.size_bytes + another_repo.size_bytes)
    end
  end

  describe '#report_metrics' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :report_metrics }

    before do
      allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:info) # avoid a flaky test if there are multiple zoekt nodes
    end

    it 'logs zoekt metadata and tasks info for nodes' do
      create(:zoekt_index, zoekt_enabled_namespace: create(:zoekt_enabled_namespace), node: node)
      create_list(:zoekt_task, 4, :pending, node: node)
      create(:zoekt_task, :done, node: node)
      create(:zoekt_task, :orphaned, node: node)
      create_list(:zoekt_task, 2, :failed, node: node)

      expect(logger).to receive(:info).with(a_hash_including(
        'class' => described_class.name,
        'meta' => a_hash_including(node.metadata_json.stringify_keys),
        'enabled_namespaces_count' => 1,
        'indices_count' => node.indices.count,
        'task_count_pending' => 4,
        'task_count_failed' => 2,
        'task_count_done' => 1,
        'task_count_orphaned' => 1,
        'task' => :report_metrics
      ))

      execute_task
    end
  end

  describe '#index_should_be_marked_as_orphaned_check' do
    let(:task) { :index_should_be_marked_as_orphaned_check }

    it 'publishes an OrphanedIndexEvent with indices that should be marked as orphaned' do
      stubbed_orphaned_indices = Search::Zoekt::Index.all

      expect(Search::Zoekt::Index).to receive_message_chain(:should_be_marked_as_orphaned,
        :each_batch).and_yield(stubbed_orphaned_indices)
      expect(stubbed_orphaned_indices).to receive(:pluck_primary_key).and_return([1, 2, 3])

      expected_data = { index_ids: [1, 2, 3] }

      expect { execute_task }
        .to publish_event(Search::Zoekt::OrphanedIndexEvent)
        .with(expected_data)
    end
  end

  describe '#index_to_delete_check' do
    let(:task) { :index_to_delete_check }

    it 'publishes an IndexMarkedAsToDeleteEvent with indices that should be deleted' do
      stubbed_orphaned_indices = Search::Zoekt::Index.all

      expect(Search::Zoekt::Index).to receive_message_chain(:should_be_deleted,
        :each_batch).and_yield(stubbed_orphaned_indices)
      expect(stubbed_orphaned_indices).to receive(:pluck_primary_key).and_return([4, 5, 6])

      expected_data = { index_ids: [4, 5, 6] }

      expect { execute_task }
        .to publish_event(Search::Zoekt::IndexMarkedAsToDeleteEvent)
        .with(expected_data)
    end
  end

  describe '#repo_should_be_marked_as_orphaned_check' do
    let(:task) { :repo_should_be_marked_as_orphaned_check }

    it 'publishes an OrphanedRepoEvent with repositories that should be marked as orphaned' do
      stubbed_orphaned_repos = Search::Zoekt::Repository.all

      expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_marked_as_orphaned,
        :each_batch).and_yield(stubbed_orphaned_repos)
      expect(stubbed_orphaned_repos).to receive(:pluck_primary_key).and_return([1, 2, 3])

      expected_data = { zoekt_repo_ids: [1, 2, 3] }

      expect { execute_task }
        .to publish_event(Search::Zoekt::OrphanedRepoEvent)
        .with(expected_data)
    end
  end

  describe '#repo_to_delete_check' do
    let(:task) { :repo_to_delete_check }

    it 'publishes an RepoMarkedAsToDeleteEvent with repos that should be deleted' do
      stubbed_orphaned_repos = Search::Zoekt::Repository.all

      expect(Search::Zoekt::Repository).to receive_message_chain(:should_be_deleted,
        :each_batch).and_yield(stubbed_orphaned_repos)
      expect(stubbed_orphaned_repos).to receive(:pluck_primary_key).and_return([4, 5, 6])

      expected_data = { zoekt_repo_ids: [4, 5, 6] }

      expect { execute_task }
        .to publish_event(Search::Zoekt::RepoMarkedAsToDeleteEvent)
        .with(expected_data)
    end
  end

  describe '#lost_nodes_check', :zoekt_settings_enabled do
    let(:task) { :lost_nodes_check }
    let_it_be_with_reload(:lost_node) { create(:zoekt_node, :lost) }

    before do
      create(:zoekt_node)
    end

    it 'publishes LostNodeEvent' do
      expect { execute_task }.to publish_event(Search::Zoekt::LostNodeEvent).with({ zoekt_node_id: lost_node.id })
    end

    context 'when there are no lost nodes' do
      before do
        Search::Zoekt::Node.update_all(last_seen_at: Time.current)
      end

      it 'does not publish LostNodeEvent' do
        expect { execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
      end
    end

    context 'when on development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'does not publish LostNodeEvent' do
        expect { execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
      end
    end

    context 'when marking_lost_enabled? is false' do
      before do
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return false
      end

      it 'does not publish LostNodeEvent' do
        expect { execute_task }.to not_publish_event(Search::Zoekt::LostNodeEvent)
      end
    end

    context 'when marking_lost_enabled? is true' do
      before do
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return true
      end

      it 'publishes LostNodeEvent' do
        expect { execute_task }.to publish_event(Search::Zoekt::LostNodeEvent).with({ zoekt_node_id: lost_node.id })
      end
    end
  end

  describe '#index_over_watermark_check' do
    let(:task) { :index_over_watermark_check }

    it 'publishes an IndexWatermarkChangedEvent with indices that use too much storage' do
      stubbed_low_watermark_indices = Search::Zoekt::Index.all
      stubbed_high_watermark_indices = Search::Zoekt::Index.all
      stubbed_overprovisioned_indices = Search::Zoekt::Index.all
      stubbed_batch = Search::Zoekt::Index.all

      expect(Search::Zoekt::Index).to receive_message_chain(:with_reserved_storage_bytes,
        :each_batch).and_yield(stubbed_batch)

      expect(stubbed_batch).to receive(
        :should_have_overprovisioned_watermark
      ).and_return(stubbed_overprovisioned_indices)
      expect(stubbed_batch).to receive(:should_have_low_watermark).and_return(stubbed_low_watermark_indices)
      expect(stubbed_batch).to receive(:should_have_high_watermark).and_return(stubbed_high_watermark_indices)

      expect(stubbed_low_watermark_indices).to receive(:pluck_primary_key).and_return([1, 2, 3])
      expect(stubbed_high_watermark_indices).to receive(:pluck_primary_key).and_return([4, 5, 6])
      expect(stubbed_overprovisioned_indices).to receive(:pluck_primary_key).and_return([7, 8, 9])

      expected_low_watermarked = { index_ids: [1, 2, 3], watermark_level: 'low_watermark_exceeded' }
      expected_high_watermarked = { index_ids: [4, 5, 6], watermark_level: 'high_watermark_exceeded' }
      expected_overprovisioned = { index_ids: [7, 8, 9], watermark_level: 'overprovisioned' }

      expect { execute_task }
        .to publish_event(Search::Zoekt::IndexWatermarkChangedEvent)
        .with(expected_low_watermarked)
        .and publish_event(Search::Zoekt::IndexWatermarkChangedEvent)
        .with(expected_high_watermarked)
        .and publish_event(Search::Zoekt::IndexWatermarkChangedEvent)
        .with(expected_overprovisioned)
    end
  end

  describe '#repo_to_index_check' do
    let(:task) { :repo_to_index_check }
    let_it_be(:pending_repo) { create(:zoekt_repository) }
    let_it_be(:initializing_repo) { create(:zoekt_repository, state: :initializing) }
    let_it_be(:ready_repo) { create(:zoekt_repository, state: :ready) }
    let_it_be(:failed_repo) { create(:zoekt_repository, state: :failed) }

    it 'publishes an RepoToIndexEvent with initializing or pending repos' do
      expected_data = { zoekt_repo_ids: [pending_repo.id, initializing_repo.id] }
      expect { execute_task }.to publish_event(Search::Zoekt::RepoToIndexEvent).with(expected_data)
    end
  end
end
