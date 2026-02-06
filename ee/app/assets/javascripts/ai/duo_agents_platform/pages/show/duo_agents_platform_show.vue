<script>
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { getAgentFlow } from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flow.query.graphql';
import { DUO_AGENTS_PLATFORM_POLLING_INTERVAL } from 'ee/ai/duo_agents_platform/constants';
import {
  formatAgentDefinition,
  formatAgentStatus,
  agentSessionStatusVar,
  agentSessionProjectVar,
  agentSessionFlowDefinitionVar,
} from 'ee/ai/duo_agents_platform/utils';
import AgentFlowDetails from './components/agent_flow_details.vue';
import AgentFlowCancelationModal from './components/agent_flow_cancelation_modal.vue';

export default {
  name: 'DuoAgentsPlatformShow',
  components: {
    AgentFlowDetails,
    AgentFlowCancelationModal,
  },
  inject: {
    isFlyout: { default: false },
    isSidePanelView: { default: false },
  },
  data() {
    return {
      agentFlow: null,
      showCancelConfirmation: false,
      isCancelling: false,
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
          agentSessionProjectVar(this.agentFlow?.project);
          agentSessionFlowDefinitionVar(this.agentFlow?.workflowDefinition);
        }
      },
      error(err) {
        createAlert({
          message:
            err?.message ||
            s__('DuoAgentsPlatform|Something went wrong while fetching Agent Flows'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.agentFlow.loading;
    },
    status() {
      return this.agentFlow?.status || '';
    },
    humanStatus() {
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
    userId() {
      return this.agentFlow?.userId || '';
    },
    workflowId() {
      return this.$route.params.id?.toString() || '';
    },
    canUpdateWorkflow() {
      return this.agentFlow?.userPermissions?.updateDuoWorkflow || false;
    },
  },
  beforeDestroy() {
    agentSessionStatusVar(null);
    agentSessionProjectVar(null);
    agentSessionFlowDefinitionVar(null);
  },
  methods: {
    async confirmCancelSession() {
      this.isCancelling = true;
      this.showCancelConfirmation = false;

      try {
        await this.cancelSessionAPI();

        createAlert({
          message: s__('DuoAgentsPlatform|Session has been cancelled successfully.'),
          variant: 'success',
        });
      } catch (error) {
        const errorMessage =
          error.response?.data?.message ||
          s__('DuoAgentsPlatform|Failed to cancel session. Please try again.');

        createAlert({
          message: errorMessage,
          captureError: true,
          variant: 'danger',
        });
      } finally {
        this.isCancelling = false;
      }
    },
    async cancelSessionAPI() {
      const { workflowId } = this;
      const url = `/api/v4/ai/duo_workflows/workflows/${workflowId}`;

      await axios.patch(url, {
        status_event: 'stop',
      });
    },
  },
};
</script>
<template>
  <div>
    <agent-flow-details
      :class="isFlyout ? 'gl-mx-3' : ''"
      :is-loading="isLoading"
      :status="status"
      :human-status="humanStatus"
      :agent-flow-definition="agentFlowDefinition"
      :duo-messages="duoMessages"
      :executor-url="executorUrl"
      :created-at="createdAt"
      :project="project"
      :updated-at="updatedAt"
      :user-id="userId"
      :workflow-id="workflowId"
      :can-update-workflow="canUpdateWorkflow"
      @cancel-session="showCancelConfirmation = true"
    />

    <agent-flow-cancelation-modal
      :visible="showCancelConfirmation"
      :loading="isCancelling"
      @hide="showCancelConfirmation = false"
      @confirm="confirmCancelSession"
    />
  </div>
</template>
