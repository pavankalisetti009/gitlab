# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SchedulingService, :clean_gitlab_redis_shared_state, feature_category: :global_search do
  let(:logger) { instance_double('Logger') }
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

  describe '#eviction' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :eviction }

    before do
      allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
    end

    it 'returns false unless saas' do
      expect(execute_task).to eq(false)
    end

    context 'when on .com', :saas do
      let_it_be(:zoekt_index) { create(:zoekt_index, node: node) }

      context 'when nodes have enough storage' do
        it 'returns false' do
          expect(logger).not_to receive(:info)
          expect { execute_task }.not_to change { Search::Zoekt::Index.count }.from(1)
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
            'watermark_limit_high' => described_class::WATERMARK_LIMIT_HIGH,
            'count' => 1 }
          )

          expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task,
            'message' => 'Unassigning namespaces from node',
            'watermark_limit_high' => described_class::WATERMARK_LIMIT_HIGH,
            'count' => 1,
            'node_used_bytes' => 90000000,
            'node_expected_used_bytes' => 27000001,
            'total_repository_size' => namespace_statistics.repository_size,
            'meta' => node_out_of_storage.metadata_json.merge('zoekt.used_bytes' => 27000001) }
          )

          expect { execute_task }.to change { Search::Zoekt::Index.count }.from(2).to(1)
          expect(zoekt_index2.zoekt_enabled_namespace.reload.search).to eq(false)
        end
      end

      it_behaves_like 'a execute_every task'
    end
  end

  describe '#dot_com_rollout' do
    let(:task) { :dot_com_rollout }

    it 'returns false unless saas' do
      expect(execute_task).to eq(false)
    end

    context 'when on .com', :saas do
      let_it_be(:group) { create(:group) }
      let_it_be(:subscription) { create(:gitlab_subscription, namespace: group) }
      let_it_be(:root_storage_statistics) { create(:namespace_root_storage_statistics, namespace: group) }

      it_behaves_like 'a execute_every task'

      it 'runs and only updates search for namespaces with assigned indices' do
        rollout_cutoff = described_class::DOT_COM_ROLLOUT_ENABLE_SEARCH_AFTER.ago - 1.hour
        ns_1 = create(:zoekt_enabled_namespace, namespace: group, search: false,
          created_at: rollout_cutoff, updated_at: rollout_cutoff)
        create(:zoekt_index, :ready, zoekt_enabled_namespace: ns_1)
        ns_2 = create(:zoekt_enabled_namespace, search: false)

        expect { execute_task }.to change { ns_1.reload.search }.from(false).to(true)
        expect { execute_task }.not_to change { ns_2.reload.search }.from(false)
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(zoekt_dot_com_rollout: false)
        end

        it 'returns false' do
          create(:zoekt_enabled_namespace)

          expect(execute_task).to eq(false)
        end
      end

      it 'enables search for namespaces' do
        rollout_cutoff = described_class::DOT_COM_ROLLOUT_ENABLE_SEARCH_AFTER.ago - 1.hour
        ns = create(:zoekt_enabled_namespace, namespace: group, search: false,
          created_at: rollout_cutoff, updated_at: rollout_cutoff)
        create(:zoekt_index, :ready, zoekt_enabled_namespace: ns)

        expect { execute_task }.to change { ns.reload.search }.from(false).to(true)
      end

      context 'when there are multiple namespaces' do
        before do
          stub_const("#{described_class}::DOT_COM_ROLLOUT_SEARCH_LIMIT", 1)
          stub_const("#{described_class}::DOT_COM_ROLLOUT_LIMIT", 0)
        end

        it 'enables the next namespace on second execution' do
          rollout_cutoff = described_class::DOT_COM_ROLLOUT_ENABLE_SEARCH_AFTER.ago - 1.hour
          ns = create(:zoekt_enabled_namespace, search: false, namespace: group,
            created_at: rollout_cutoff, updated_at: rollout_cutoff)
          create(:zoekt_index, :ready, zoekt_enabled_namespace: ns)

          group2 = create(:group)
          ns2 = create(:zoekt_enabled_namespace, search: false, namespace: group2,
            created_at: rollout_cutoff, updated_at: rollout_cutoff)
          create(:zoekt_index, :ready, zoekt_enabled_namespace: ns2)

          expect { execute_task }.to change { ns.reload.search }.from(false).to(true)

          expect { service.execute }.to change { ns2.reload.search }.from(false).to(true)
        end
      end

      it 'skips recently enabled namespaces' do
        ns = create(:zoekt_enabled_namespace, namespace: group, search: false)
        create(:zoekt_index, :ready, zoekt_enabled_namespace: ns)

        expect { execute_task }.not_to change { ns.reload.search }
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
      expect(execute_task).to eq(false)
    end

    context 'when on .com', :saas do
      let_it_be(:expiration_date) { Date.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD }
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
    let_it_be(:namespace_statistics) { create(:namespace_root_storage_statistics, repository_size: 1000) }
    let_it_be(:namespace_with_statistics) { create(:group, root_storage_statistics: namespace_statistics) }

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_node_assignment: false)
      end

      it 'returns false' do
        expect(execute_task).to eq(false)
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
          expect(execute_task).to eq(false)
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
                                                          'message' => 'Space is not available in Node',
                                                          'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id,
                                                          'meta' => node.metadata_json }
          )
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
                                                    'message' => 'Space is not available in Node',
                                                    'zoekt_enabled_namespace_id' => zkt_enabled_namespace2.id,
                                                    'meta' => node.metadata_json }
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

        it 'creates a record of Search::Zoekt::Index for the namespace which has statistics' do
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

        context 'when feature flag zoekt_initial_indexing_task is disabled' do
          before do
            stub_feature_flags(zoekt_initial_indexing_task: false)
          end

          it 'creates a record of Search::Zoekt::Index with state ready' do
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
    end
  end

  describe '#mark_indices_as_ready' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:task) { :mark_indices_as_ready }
    let_it_be(:idx) { create(:zoekt_index, state: :initializing) } # It has some pending zoekt_repositories
    let_it_be(:idx2) { create(:zoekt_index, state: :initializing) } # It has all ready zoekt_repositories
    let_it_be(:idx3) { create(:zoekt_index, state: :initializing) } # It does not have zoekt_repositories
    let_it_be(:idx4) { create(:zoekt_index) } # It has all ready zoekt_repositories but zoekt_index is pending
    let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
    let_it_be(:idx_project2) { create(:project, namespace_id: idx.namespace_id) }
    let_it_be(:idx2_project2) { create(:project, namespace_id: idx2.namespace_id) }
    let_it_be(:idx4_project) { create(:project, namespace_id: idx4.namespace_id) }

    before do
      allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
    end

    context 'when indices can not be moved to ready' do
      it 'does not change any state' do
        initial_indices_state = [idx, idx2, idx3, idx4].map { |i| i.reload.state }
        expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task, 'count' => 0,
                                                'message' => 'Set indices ready' }
        )
        execute_task
        expect([idx, idx2, idx3, idx4].map { |i| i.reload.state }).to eq(initial_indices_state)
      end
    end

    context 'when indices can be moved to ready' do
      before do
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :pending)
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project2, state: :ready)
        idx2.zoekt_repositories.create!(zoekt_index: idx2, project: idx2_project2, state: :ready)
        idx4.zoekt_repositories.create!(zoekt_index: idx4, project: idx4_project, state: :ready)
      end

      it 'moves to ready only those initializing indices that have all ready zoekt_repositories' do
        expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'task' => task, 'count' => 1,
                                                'message' => 'Set indices ready' }
        )
        execute_task
        expect([idx, idx2, idx3, idx4].map { |i| i.reload.state }).to eq(%w[initializing ready initializing pending])
      end
    end
  end

  describe '#initial_indexing' do
    let(:task) { :initial_indexing }

    context 'when feature flag zoekt_initial_indexing_task is disabled' do
      before do
        stub_feature_flags(zoekt_initial_indexing_task: false)
      end

      it 'returns false' do
        expect(execute_task).to eq(false)
      end
    end

    context 'when there are no zoekt_indices in_progress' do
      let_it_be(:index) { create(:zoekt_index, state: :pending) }

      it 'does not moves the index to initializing and calls NamespaceInitialIndexingWorker on the index' do
        expect(Search::Zoekt::NamespaceInitialIndexingWorker).to receive(:bulk_perform_in_with_contexts)
          .with(anything, [index], hash_including(:arguments_proc, :context_proc))
        expect { execute_task }.not_to change { index.reload.state }
      end
    end

    context 'when all zoekt_indices are already in progress' do
      let_it_be(:idx_in_progress) { create(:zoekt_index, state: :in_progress) }
      let_it_be(:namespace) { idx_in_progress.zoekt_enabled_namespace.namespace }

      context 'when there are no pending indices' do
        context 'when zoekt_repositories count is less than all the projects within the namespace' do
          before do
            create(:project, namespace: namespace)
          end

          it 'does not moves the index to initializing' do
            expect { execute_task }.not_to change { idx_in_progress.reload.state }
          end
        end

        context 'when zoekt_repositories count is equal to all the projects within the namespace' do
          let(:logger) { instance_double(::Search::Zoekt::Logger) }
          let_it_be(:project) { create(:project, namespace: namespace) }

          before do
            allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
            create(:zoekt_repository, zoekt_index: idx_in_progress, project_id: project.id,
              project_identifier: project.id)
          end

          it 'moves the index to initializing and do the logging' do
            node = idx_in_progress.node
            meta = node.metadata_json.merge('zoekt.index_id' => idx_in_progress.id)
            expect(logger).to receive(:info).with({ 'class' => described_class.to_s, 'namespace_id' => namespace.id,
                                                    'message' => 'index moved to initializing',
                                                    'meta' => meta,
                                                    'repo_count' => idx_in_progress.zoekt_repositories.count,
                                                    'project_count' => namespace.all_projects.count, 'task' => task }
            )
            expect { execute_task }.to change { idx_in_progress.reload.state }.from('in_progress').to('initializing')
          end
        end
      end
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
        expect(execute_task).to eq(false)
      end
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
      create_list(:zoekt_task, 4, :pending, node: node)
      create(:zoekt_task, :done, node: node)
      create(:zoekt_task, :orphaned, node: node)
      create_list(:zoekt_task, 2, :failed, node: node)

      expect(logger).to receive(:info).with(a_hash_including(
        'class' => described_class.name,
        'meta' => a_hash_including(node.metadata_json.stringify_keys),
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
end
