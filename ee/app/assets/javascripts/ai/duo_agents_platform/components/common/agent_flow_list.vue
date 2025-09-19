<script>
import { GlEmptyState, GlKeysetPagination } from '@gitlab/ui';
import emptyStateIllustrationPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg';
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
    showProjectInfo: {
      required: false,
      type: Boolean,
      default: false,
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
    displayPagination() {
      return this.workflowsPageInfo?.hasNextPage || this.workflowsPageInfo?.hasPreviousPage;
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
  emptyStateIllustrationPath,
};
</script>
<template>
  <div>
    <gl-empty-state
      v-if="!hasWorkflows"
      :title="s__('DuoAgentsPlatform|No agent sessions yet')"
      :description="s__('DuoAgentsPlatform|New agent sessions will appear here.')"
      :svg-path="$options.emptyStateIllustrationPath"
    />
    <template v-else>
      <ul class="gl-divide-x-0 gl-divide-y-1 gl-divide-solid gl-divide-gray-100 gl-px-0 gl-pt-4">
        <agent-flow-list-item
          v-for="item in workflows"
          :key="item.id"
          :item="item"
          :show-project-info="showProjectInfo"
        />
      </ul>
      <gl-keyset-pagination
        v-if="displayPagination"
        v-bind="workflowsPageInfo"
        class="gl-mt-5 gl-flex gl-justify-center"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </template>
  </div>
</template>
