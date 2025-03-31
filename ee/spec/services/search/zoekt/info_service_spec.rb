# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::InfoService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }
  let(:settings) { instance_double(ApplicationSetting) }
  let(:current_time) { Time.current.change(usec: 0) }
  let(:version_info) { Gitlab::VersionInfo.new(15, 0, 0) }
  let(:online_relation) { instance_double(ActiveRecord::Relation, count: 0, to_a: []) }

  before do
    allow(logger).to receive(:info)
    allow(ApplicationSetting).to receive(:current).and_return(settings)
    allow(settings).to receive_messages(
      zoekt_indexing_enabled: true,
      zoekt_search_enabled: true,
      zoekt_indexing_paused: false,
      zoekt_auto_delete_lost_nodes: true,
      zoekt_auto_index_root_namespace: true,
      zoekt_cpu_to_tasks_ratio: 1.5,
      zoekt_rollout_batch_size: 32
    )
    allow(Gitlab).to receive(:version_info).and_return(version_info)
    allow(Feature).to receive_messages(
      current_request: nil,
      enabled?: false,
      persisted_name?: false
    )
    allow(Search::Zoekt::Node).to receive_messages(
      count: 0,
      online: online_relation,
      sum: 0,
      maximum: nil
    )
    allow(Search::Zoekt::Index).to receive(:sum).and_return(0)
  end

  describe '#execute' do
    context 'when displaying settings section' do
      it 'displays settings information' do
        service.execute

        expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Exact Code Search').bright.yellow.underline}")
        expect(logger).to have_received(:info).with(/GitLab version:.+/)
        expect(logger).to have_received(:info).with(/Enable indexing:.+#{Rainbow('yes').green}/)
        expect(logger).to have_received(:info).with(/Enable searching:.+#{Rainbow('yes').green}/)
        expect(logger).to have_received(:info).with(/Pause indexing:.+no/)
        expect(logger).to have_received(:info).with(/Index root namespaces automatically:.+#{Rainbow('yes').green}/)
        expect(logger).to have_received(:info).with(
          /Delete offline nodes after 12 hours:.+#{Rainbow('yes').green}/
        )
        expect(logger).to have_received(:info).with(/Indexing CPU to tasks multiplier:.+1.5/)
      end
    end

    context 'when displaying nodes section with no nodes' do
      before do
        empty_online_relation = instance_double(ActiveRecord::Relation, count: 0, to_a: [])
        allow(Search::Zoekt::Node).to receive_messages(
          online: empty_online_relation,
          count: 0,
          maximum: nil
        )
      end

      it 'displays empty node watermark levels' do
        service.execute

        expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Nodes').bright.yellow.underline}")
        expect(logger).to have_received(:info).with(
          /Node count:.+0 \(online: #{Rainbow('0').green}, offline: #{Rainbow('0').red}\)/
        )
        expect(logger).to have_received(:info).with(/Online node watermark levels:.+#{Rainbow('\(none\)').yellow}/)
      end
    end

    context 'when displaying nodes section with online nodes' do
      let(:node1) do
        instance_double(Search::Zoekt::Node, watermark_exceeded_critical?: true, watermark_exceeded_high?: true,
          watermark_exceeded_low?: true)
      end

      let(:node2) do
        instance_double(Search::Zoekt::Node, watermark_exceeded_critical?: false, watermark_exceeded_high?: true,
          watermark_exceeded_low?: true)
      end

      let(:node3) do
        instance_double(Search::Zoekt::Node, watermark_exceeded_critical?: false, watermark_exceeded_high?: false,
          watermark_exceeded_low?: true)
      end

      let(:node4) do
        instance_double(Search::Zoekt::Node, watermark_exceeded_critical?: false, watermark_exceeded_high?: false,
          watermark_exceeded_low?: false)
      end

      let(:online_nodes) { [node1, node2, node3, node4] }
      let(:nodes_online_relation) { instance_double(ActiveRecord::Relation, count: 4, to_a: online_nodes) }

      before do
        allow(Search::Zoekt::Node).to receive_messages(
          online: nodes_online_relation,
          count: 5,
          maximum: current_time
        )
        allow(Search::Zoekt::Node).to receive_messages(
          sum: 0 # default for any non-specific call
        )
        allow(Search::Zoekt::Node).to receive(:sum).with(:usable_storage_bytes).and_return(10 * 1024 * 1024) # 10MB
        allow(Search::Zoekt::Node).to receive(:sum).with(:indexed_bytes).and_return(5 * 1024 * 1024) # 5MB
        allow(Search::Zoekt::Node).to receive(:sum).with(:used_bytes).and_return(6 * 1024 * 1024) # 6MB
        allow(Search::Zoekt::Node).to receive(:sum).with(:total_bytes).and_return(20 * 1024 * 1024) # 20MB
        allow(Search::Zoekt::Index).to receive(:sum).with(:reserved_storage_bytes).and_return(8 * 1024 * 1024) # 8MB
        allow(Search::Zoekt::Node).to receive(:maximum).with(:last_seen_at).and_return(current_time)
      end

      it 'displays node information' do
        travel_to(current_time) do
          service.execute

          expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Nodes').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(
            /Node count:.+5 \(online: #{Rainbow('4').green}, offline: #{Rainbow('1').red}\)/
          )
          # Test the new node watermark levels section
          expect(logger).to have_received(:info).with(/Online node watermark levels:.+4/)
          # Check for the individual watermark counts
          expect(logger).to have_received(:info).with(/  - critical: 1/)
          expect(logger).to have_received(:info).with(/  - high: 1/)
          expect(logger).to have_received(:info).with(/  - low: 1/)
          expect(logger).to have_received(:info).with(/  - normal: 1/)

          expect(logger).to have_received(:info).with(/Last seen at:.+#{current_time.utc}/)
          # Match MiB format
          expect(logger).to have_received(:info).with(
            %r{Storage reserved / usable:.+8 MiB / 10 MiB}
          )
          expect(logger).to have_received(:info).with(
            %r{Storage indexed / reserved:.+5 MiB / 8 MiB}
          )
          expect(logger).to have_received(:info).with(
            %r{Storage used / total:.+6 MiB / 20 MiB}
          )
        end
      end
    end

    context 'when displaying indexing status' do
      before do
        allow(Group).to receive_message_chain(:top_level, :count).and_return(10)
        allow(Search::Zoekt::EnabledNamespace).to receive_messages(
          count: 0,
          with_missing_indices: instance_double(ActiveRecord::Relation, count: 0),
          search_disabled: instance_double(ActiveRecord::Relation, count: 0)
        )

        # Ensure empty online nodes array for all indexing status tests
        empty_online_relation = instance_double(ActiveRecord::Relation, count: 0, to_a: [])
        allow(Search::Zoekt::Node).to receive(:online).and_return(empty_online_relation)
      end

      context 'with no data' do
        before do
          replica_group_relation = instance_double(ActiveRecord::Relation, count: {})
          index_group_relation = instance_double(ActiveRecord::Relation, count: {})
          index_watermark_group = instance_double(ActiveRecord::Relation, count: {})
          repository_group_relation = instance_double(ActiveRecord::Relation, count: {})
          task_group_relation = instance_double(ActiveRecord::Relation, count: {})
          task_type_group_relation = instance_double(ActiveRecord::Relation, count: {})
          pending_tasks_relation = instance_double(ActiveRecord::Relation)

          allow(Search::Zoekt::Replica).to receive(:group).with(:state).and_return(replica_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:state).and_return(index_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:watermark_level)
                                     .and_return(index_watermark_group)
          allow(Search::Zoekt::Repository).to receive(:group).with(:state).and_return(repository_group_relation)
          allow(Search::Zoekt::Task).to receive(:group).with(:state).and_return(task_group_relation)
          allow(Search::Zoekt::Task).to receive(:pending_or_processing).and_return(pending_tasks_relation)
          allow(pending_tasks_relation).to receive(:group).with(:task_type).and_return(task_type_group_relation)
        end

        it 'displays zero counts with (none)' do
          service.execute

          expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Indexing status').bright.yellow.underline}")

          # Verify the new Group count information is displayed
          expect(logger).to have_received(:info).with(/Group count:.+10/)

          namespace_msg = /EnabledNamespace count:.+0 \(without indices: #{Rainbow('0').red}, /
          namespace_msg_part2 = /with search disabled: #{Rainbow('0').yellow}\)/
          expect(logger).to have_received(:info).with(namespace_msg)
          expect(logger).to have_received(:info).with(namespace_msg_part2)

          expect(logger).to have_received(:info).with(/Replicas count:.+\(none\)/)
          expect(logger).to have_received(:info).with(/Indices count:.+\(none\)/)
          expect(logger).to have_received(:info).with(/Repositories count:.+\(none\)/)
        end
      end

      context 'with data' do
        before do
          # Create stubs for all the necessary group/count combinations
          replica_group_relation = instance_double(ActiveRecord::Relation, count: { 'ready' => 2, 'pending' => 1 })
          index_group_relation = instance_double(ActiveRecord::Relation, count: { 'ready' => 2, 'pending' => 1 })
          index_watermark_group = instance_double(ActiveRecord::Relation, count: { 'ok' => 2, 'warning' => 1 })
          repository_group_relation = instance_double(ActiveRecord::Relation, count: { 'ready' => 2, 'orphaned' => 1 })
          task_group_relation = instance_double(ActiveRecord::Relation,
            count: { 'done' => 2, 'failed' => 1, 'pending' => 1 })
          task_type_relation = instance_double(ActiveRecord::Relation,
            count: { 'update_repository' => 1, 'delete_repository' => 1 })
          pending_tasks_relation = instance_double(ActiveRecord::Relation)

          allow(Search::Zoekt::Replica).to receive(:group).with(:state).and_return(replica_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:state).and_return(index_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:watermark_level)
                                     .and_return(index_watermark_group)
          allow(Search::Zoekt::Repository).to receive(:group).with(:state).and_return(repository_group_relation)
          allow(Search::Zoekt::Task).to receive(:group).with(:state).and_return(task_group_relation)
          allow(Search::Zoekt::Task).to receive(:pending_or_processing).and_return(pending_tasks_relation)
          allow(pending_tasks_relation).to receive(:group).with(:task_type).and_return(task_type_relation)
        end

        it 'displays counts with state breakdowns' do
          service.execute

          expect(logger).to have_received(:info).with("\n#{Rainbow('Indexing status').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(/Group count:.+10/)
          expect(logger).to have_received(:info).with(/EnabledNamespace count:.+0/)
          expect(logger).to have_received(:info).with(/Replicas count:.+3/)
        end
      end
    end

    context 'when displaying feature flags section' do
      before do
        allow(Feature).to receive(:persisted_names).and_return(['zoekt_custom_flag'])

        zoekt_flag = instance_double(Feature::Definition, to_s: 'zoekt_default_flag')

        # Combine all Feature::Definition stubs
        allow(Feature::Definition).to receive_messages(
          definitions: { 'zoekt_default_flag' => zoekt_flag },
          has_definition?: false
        )

        # Set up specific has_definition? calls that override the default
        allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_custom_flag).and_return(true)
        allow(Feature::Definition).to receive(:has_definition?).with('zoekt_custom_flag').and_return(true)
        allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_default_flag).and_return(true)
        allow(Feature::Definition).to receive(:has_definition?).with('zoekt_default_flag').and_return(true)

        allow(Feature).to receive(:persisted_name?).with('zoekt_default_flag').and_return(false)
        allow(Feature).to receive(:enabled?).with('zoekt_custom_flag', nil).and_return(true)
        allow(Feature).to receive(:enabled?).with('zoekt_default_flag', nil).and_return(false)
      end

      it 'displays custom feature flags section' do
        service.execute

        header_text = "\n#{Rainbow('Feature Flags (Non-Default Values)').bright.yellow.underline}"
        expect(logger).to have_received(:info).with(header_text)
      end

      it 'displays default feature flags section' do
        service.execute

        header_text = "\n#{Rainbow('Feature Flags (Default Values)').bright.yellow.underline}"
        expect(logger).to have_received(:info).with(header_text)
      end

      context 'with no feature flags' do
        before do
          allow(Feature).to receive_messages(
            persisted_names: [],
            persisted_name?: false,
            enabled?: false
          )
          allow(Feature::Definition).to receive_messages(
            definitions: {},
            has_definition?: false
          )
        end

        it 'displays empty feature flags sections' do
          service.execute

          # Expect header for non-default values section
          non_default_header = "\n#{Rainbow('Feature Flags (Non-Default Values)').bright.yellow.underline}"
          expect(logger).to have_received(:info).with(non_default_header)

          # Expect header for default values section
          default_header = "\n#{Rainbow('Feature Flags (Default Values)').bright.yellow.underline}"
          expect(logger).to have_received(:info).with(default_header)

          # Check for the 'none' message without specifying exactly how many times
          expect(logger).to have_received(:info).with(/Feature flags:.+#{Rainbow('none').yellow}/).at_least(:once)
        end
      end

      context 'with feature flags without YAML definitions' do
        before do
          allow(Feature).to receive(:persisted_names).and_return(%w[zoekt_custom_flag zoekt_undefined_flag])

          # Set up has_definition? to return appropriate values for both string and symbol keys
          allow(Feature::Definition).to receive(:has_definition?).and_return(false)
          allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_custom_flag).and_return(true)
          allow(Feature::Definition).to receive(:has_definition?).with('zoekt_custom_flag').and_return(true)
          allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_undefined_flag).and_return(false)
          allow(Feature::Definition).to receive(:has_definition?).with('zoekt_undefined_flag').and_return(false)
          allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_default_flag).and_return(true)
          allow(Feature::Definition).to receive(:has_definition?).with('zoekt_default_flag').and_return(true)

          # We should never call enabled? on the undefined flag
          allow(Feature).to receive(:enabled?).with('zoekt_undefined_flag', nil)
            .and_raise('This should not be called')
        end

        it 'displays flags without definitions as "no definition"' do
          service.execute

          # The flag with no definition should show up in the output
          expect(logger).to have_received(:info).with(/- zoekt_undefined_flag:.+#{Rainbow('no definition').yellow}/)

          # The regular flag should still work
          expect(logger).to have_received(:info).with(/- zoekt_custom_flag:.+#{Rainbow('enabled').green}/)
        end
      end
    end
  end
end
