<script>
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { getAgentFlow } from '../../graphql/queries/get_agent_flow.query.graphql';
import { DUO_AGENTS_PLATFORM_POLLING_INTERVAL } from '../../constants';
import { formatAgentDefinition, formatAgentStatus, agentSessionStatusVar } from '../../utils';
import AgentFlowDetails from './components/agent_flow_details.vue';

export default {
  name: 'DuoAgentsPlatformShow',
  components: { AgentFlowDetails },
  inject: {
    isFlyout: { default: false },
    isSidePanelView: { default: false },
  },
  data() {
    return {
      agentFlow: null,
    };
  },
  apollo: {
    agentFlow: {
      query: getAgentFlow,
      pollInterval: DUO_AGENTS_PLATFORM_POLLING_INTERVAL,
      variables() {
        return {
          workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, this.$route.params.id),
        };
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.[0]?.node || {};
      },
      result() {
        if (this.isSidePanelView) {
          agentSessionStatusVar(this.agentFlow?.status);
        }
      },
      error(err) {
        createAlert({
          message:
            err?.message ||
            s__('DuoAgentsPlatform|Something went wrong while fetching Agent Flows'),
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.agentFlow.loading;
    },
    status() {
      return formatAgentStatus(this.agentFlow?.humanStatus);
    },
    agentFlowDefinition() {
      return formatAgentDefinition(this.agentFlow?.workflowDefinition);
    },
    duoMessages() {
      return this.agentFlow?.latestCheckpoint?.duoMessages || [];
    },
    executorUrl() {
      return this.agentFlow?.lastExecutorLogsUrl || '';
    },
    createdAt() {
      return this.agentFlow?.createdAt || '';
    },
    updatedAt() {
      return this.agentFlow?.updatedAt || '';
    },
    project() {
      return this.agentFlow?.project || {};
    },
  },
  beforeDestroy() {
    agentSessionStatusVar(null);
  },
};
</script>
<template>
  <agent-flow-details
    :class="isFlyout ? 'gl-mx-3' : ''"
    :is-loading="isLoading"
    :status="status"
    :agent-flow-definition="agentFlowDefinition"
    :duo-messages="duoMessages"
    :executor-url="executorUrl"
    :created-at="createdAt"
    :project="project"
    :updated-at="updatedAt"
  />
</template>
