<script>
import { GlTabs, GlTab } from '@gitlab/ui';
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
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    status: {
      required: true,
      type: String,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
    agentFlowCheckpoint: {
      type: String,
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
  },
};
</script>
<template>
  <div>
    <agent-flow-header :is-loading="isLoading" :agent-flow-definition="agentFlowDefinition" />
    <div class="gl-mt-6 gl-flex">
      <gl-tabs class="gl-w-full" content-class="gl-py-0">
        <gl-tab :title="s__('DuoAgentPlatform|Activity')">
          <agent-activity-logs
            class="gl-overflow-auto"
            :is-loading="isLoading"
            :agent-flow-checkpoint="agentFlowCheckpoint"
          />
        </gl-tab>
        <gl-tab :title="s__('DuoAgentPlatform|Details')">
          <agent-flow-info
            class="gl-mt-5"
            :is-loading="isLoading"
            :status="status"
            :agent-flow-definition="agentFlowDefinition"
            :created-at="createdAt"
            :updated-at="updatedAt"
            :executor-url="executorUrl"
          />
        </gl-tab>
      </gl-tabs>
    </div>
  </div>
</template>
