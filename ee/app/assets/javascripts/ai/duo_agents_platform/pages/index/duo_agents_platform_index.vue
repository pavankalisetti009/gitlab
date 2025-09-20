<script>
import { GlButton, GlExperimentBadge, GlLoadingIcon } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AgentFlowList from '../../components/common/agent_flow_list.vue';
import { AGENTS_PLATFORM_NEW_ROUTE } from '../../router/constants';
import { AGENT_PLATFORM_INDEX_COMPONENT_NAME } from '../../constants';

export default {
  name: AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  components: {
    AgentFlowList,
    GlButton,
    GlExperimentBadge,
    GlLoadingIcon,
    PageHeading,
  },
  inject: {
    isSidePanelView: {
      default: false,
    },
  },
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
  computed: {
    headerClass() {
      return this.isSidePanelView ? 'gl-mt-0' : '';
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
  <div class="gl-flex gl-flex-col">
    <page-heading v-if="!isSidePanelView" :class="headerClass">
      <template #heading>
        <div class="gl-flex">
          <span>{{ s__('DuoAgentsPlatform|Agent sessions') }}</span>
          <gl-experiment-badge type="beta" class="gl-self-center" />
        </div>
      </template>
      <template #actions>
        <gl-button
          v-if="!isSidePanelView"
          variant="confirm"
          :to="{ name: $options.newPage }"
          data-testid="new-agent-flow-button"
          >{{ s__('DuoAgentsPlatform|New session') }}</gl-button
        >
      </template>
    </page-heading>
    <gl-loading-icon v-if="isLoadingWorkflows" size="lg" />
    <agent-flow-list
      v-else
      :show-project-info="isSidePanelView"
      :workflows="workflows"
      :workflows-page-info="workflowsPageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
  </div>
</template>
