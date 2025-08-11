<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import getProjectAiFlowTriggers from 'ee/ai/duo_agents_platform/graphql/queries/get_ai_flow_triggers.query.graphql';
import FlowTriggersCta from './components/flow_triggers_cta.vue';
import FlowTriggersTable from './components/flow_triggers_table.vue';

export default {
  name: 'FlowTriggersIndex',
  components: {
    FlowTriggersCta,
    FlowTriggersTable,
    PageHeading,
    ResourceListsEmptyState,
    ResourceListsLoadingStateList,
  },
  inject: ['emptyStateIllustrationPath', 'projectPath'],
  data() {
    return {
      aiFlowTriggers: [],
    };
  },
  apollo: {
    aiFlowTriggers: {
      query: getProjectAiFlowTriggers,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update: (data) => data.project.aiFlowTriggers.nodes,
      error(error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to fetch flow triggers'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiFlowTriggers.loading;
    },
    showEmptyState() {
      return !this.isLoading && this.aiFlowTriggers.length === 0;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('DuoAgentsPlatform|Flow triggers')">
      <template #description>
        {{ s__('DuoAgentsPlatform|Manage automated flows within your project.') }}
      </template>
      <template #actions>
        <flow-triggers-cta />
      </template>
    </page-heading>
    <resource-lists-loading-state-list
      v-if="isLoading"
      :left-lines-count="1"
      :right-lines-count="1"
    />
    <resource-lists-empty-state
      v-else-if="showEmptyState"
      :title="s__('DuoAgentsPlatform|No flow triggers yet')"
      :description="
        s__(
          'DuoAgentsPlatform|Create flow triggers to automatically run pipelines when specified events occur in your project.',
        )
      "
      :svg-path="emptyStateIllustrationPath"
    >
      <template #actions>
        <slot name="actions">
          <flow-triggers-cta />
        </slot>
      </template>
    </resource-lists-empty-state>
    <flow-triggers-table v-else :ai-flow-triggers="aiFlowTriggers" class="gl-mt-8" />
  </div>
</template>
