<script>
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import AgentFlowList from '../../components/common/agent_flow_list.vue';
import { AGENTS_PLATFORM_NEW_ROUTE } from '../../router/constants';
import { AGENT_PLATFORM_INDEX_COMPONENT_NAME } from '../../constants';

export default {
  name: AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  components: {
    GlButton,
    GlLoadingIcon,
    AgentFlowList,
  },
  inject: ['emptyStateIllustrationPath'],
  props: {
    workflowQuery: {
      required: true,
      type: Object,
    },
    workflows: {
      required: true,
      type: Array,
    },
    workflowsPageInfo: {
      required: true,
      type: Object,
    },
    isLoadingWorkflows: {
      required: true,
      type: Boolean,
    },
  },
  methods: {
    handleNextPage() {
      this.workflowQuery.refetch({
        ...this.workflowQuery.variables,
        before: null,
        after: this.workflowsPageInfo.endCursor,
        first: 20,
        last: null,
      });
    },
    handlePrevPage() {
      this.workflowQuery.refetch({
        ...this.workflowQuery.variables,
        after: null,
        before: this.workflowsPageInfo.startCursor,
        first: null,
        last: 20,
      });
    },
  },
  newPage: AGENTS_PLATFORM_NEW_ROUTE,
};
</script>
<template>
  <div class="gl-mt-3 gl-flex gl-flex-col">
    <div class="gl-flex gl-justify-end">
      <gl-button
        variant="confirm"
        :to="{ name: $options.newPage }"
        data-testid="new-agent-flow-button"
        >{{ s__('DuoAgentsPlatform|New session') }}</gl-button
      >
    </div>
    <gl-loading-icon v-if="isLoadingWorkflows" size="lg" />
    <agent-flow-list
      v-else
      class="gl-mt-5"
      :empty-state-illustration-path="emptyStateIllustrationPath"
      :workflows="workflows"
      :workflows-page-info="workflowsPageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
  </div>
</template>
