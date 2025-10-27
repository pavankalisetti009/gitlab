import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import deleteAgenticWorkflowMutation from 'ee/ai/graphql/delete_agentic_workflow.mutation.graphql';
import getWorkflowEventsQuery from 'ee/ai/graphql/get_workflow_events.query.graphql';
import getAgentFlowConfig from 'ee/ai/graphql/get_agent_flow_config.query.graphql';
import {
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_AGENT_PRIVILEGES,
  DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
} from 'ee/ai/constants';
import { fetchPolicies } from '~/lib/graphql';
import { parseGid } from '~/graphql_shared/utils';
import { MULTI_THREADED_CONVERSATION_TYPE } from '../../tanuki_bot/constants';

export const ApolloUtils = {
  async createWorkflow(
    apollo,
    { projectId, workflowDefinition, namespaceId, goal, activeThread, aiCatalogItemVersionId },
  ) {
    const variables = {
      goal,
      workflowDefinition: workflowDefinition || DUO_WORKFLOW_CHAT_DEFINITION,
      agentPrivileges: DUO_WORKFLOW_AGENT_PRIVILEGES,
      preApprovedAgentPrivileges: DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
      threadId: activeThread,
      conversationType: MULTI_THREADED_CONVERSATION_TYPE,
    };

    if (projectId) variables.projectId = projectId;
    if (namespaceId) variables.namespaceId = namespaceId;
    if (aiCatalogItemVersionId) variables.aiCatalogItemVersionId = aiCatalogItemVersionId;

    const result = await apollo.mutate({
      mutation: duoWorkflowMutation,
      variables,
      context: {
        headers: {
          'X-GitLab-Interface': 'duo_chat',
          'X-GitLab-Client-Type': 'web_browser',
        },
      },
    });

    const errors = result?.data?.aiDuoWorkflowCreate?.errors;
    if (errors && errors.length > 0) {
      throw new Error(errors.join(', '));
    }

    const workflow = result?.data?.aiDuoWorkflowCreate?.workflow || {};

    return {
      workflowId: workflow.id ? parseGid(workflow.id).id : null,
      threadId: workflow.threadId || null,
    };
  },

  async deleteWorkflow(apollo, workflowId) {
    const { data } = await apollo.mutate({
      mutation: deleteAgenticWorkflowMutation,
      variables: { input: { workflowId } },
    });

    return data?.deleteDuoWorkflowsWorkflow?.success;
  },

  async fetchWorkflowEvents(apollo, workflowId) {
    const { data } = await apollo.query({
      query: getWorkflowEventsQuery,
      variables: { workflowId },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
    });

    return data;
  },

  async getAgentFlowConfig(apollo, agentVersionId) {
    const { data } = await apollo.query({
      query: getAgentFlowConfig,
      variables: { agentVersionId },
    });

    return data?.aiCatalogAgentFlowConfig;
  },
};
