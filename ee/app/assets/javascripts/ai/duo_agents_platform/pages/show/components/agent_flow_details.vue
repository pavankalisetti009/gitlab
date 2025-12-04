<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import { AGENTS_PLATFORM_INDEX_ROUTE } from '../../../router/constants';
import AgentFlowHeader from './agent_flow_header.vue';
import AgentFlowInfo from './agent_flow_info.vue';
import AgentActivityLogs from './agent_activity_logs.vue';

export default {
  name: 'AgentFlowDetails',
  components: {
    AgentFlowHeader,
    AgentFlowInfo,
    AgentActivityLogs,
    GlTabs,
    GlTab,
  },
  inject: { isSidePanelView: { default: false } },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    status: {
      required: true,
      type: String,
    },
    humanStatus: {
      required: true,
      type: String,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
    duoMessages: {
      type: Array,
      required: true,
    },
    executorUrl: {
      type: String,
      required: false,
      default: '',
    },
    createdAt: {
      type: String,
      required: true,
    },
    updatedAt: {
      type: String,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
  },
  AGENTS_PLATFORM_INDEX_ROUTE,
};
</script>
<template>
  <div>
    <agent-flow-header
      v-if="!isSidePanelView"
      :is-loading="isLoading"
      :agent-flow-definition="agentFlowDefinition"
    />
    <div class="gl-flex" :class="{ 'gl-mt-6': !isSidePanelView }">
      <gl-tabs class="gl-w-full" content-class="gl-py-0">
        <gl-tab :title="s__('DuoAgentPlatform|Activity')">
          <agent-activity-logs
            class="gl-overflow-auto"
            :is-loading="isLoading"
            :duo-messages="duoMessages"
          />
        </gl-tab>
        <gl-tab :title="s__('DuoAgentPlatform|Details')">
          <agent-flow-info
            class="gl-mt-6"
            :is-loading="isLoading"
            :status="status"
            :human-status="humanStatus"
            :agent-flow-definition="agentFlowDefinition"
            :created-at="createdAt"
            :project="project"
            :updated-at="updatedAt"
            :executor-url="executorUrl"
          />
        </gl-tab>
      </gl-tabs>
    </div>
  </div>
</template>
