<script>
import { GlEmptyState, GlKeysetPagination } from '@gitlab/ui';
import { AGENTS_PLATFORM_SHOW_ROUTE } from '../../router/constants';
import AgentFlowListItem from './agent_flow_list_item.vue';

export default {
  name: 'AgentFlowList',
  components: {
    GlEmptyState,
    GlKeysetPagination,
    AgentFlowListItem,
  },
  props: {
    emptyStateIllustrationPath: {
      required: true,
      type: String,
    },
    workflows: {
      required: true,
      type: Array,
    },
    workflowsPageInfo: {
      required: true,
      type: Object,
    },
  },
  computed: {
    hasWorkflows() {
      return this.workflows?.length > 0;
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
};
</script>
<template>
  <div>
    <gl-empty-state
      v-if="!hasWorkflows"
      :title="s__('DuoAgentsPlatform|No agent sessions yet')"
      :description="s__('DuoAgentsPlatform|New agent sessions will appear here.')"
      :svg-path="emptyStateIllustrationPath"
    />
    <template v-else>
      <ul class="gl-px-0 gl-pt-4">
        <agent-flow-list-item v-for="item in workflows" :key="item.id" :item="item" />
      </ul>
      <gl-keyset-pagination
        v-bind="workflowsPageInfo"
        class="gl-mt-5 gl-flex gl-justify-center"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </template>
  </div>
</template>
