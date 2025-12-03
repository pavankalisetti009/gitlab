import { parseDocument } from 'yaml';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { parseMessage } from '~/lib/utils/websocket_utils';
import {
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_CLIENT_VERSION,
  DUO_WORKFLOW_WEBSOCKET_BASE_URL,
  DUO_WORKFLOW_WEBSOCKET_PARAM_ROOT_NAMESPACE_ID,
  DUO_WORKFLOW_WEBSOCKET_PARAM_NAMESPACE_ID,
  DUO_WORKFLOW_WEBSOCKET_PARAM_PROJECT_ID,
  DUO_WORKFLOW_WEBSOCKET_PARAM_USER_SELECTED_MODEL,
} from 'ee/ai/constants';
import { WorkflowUtils } from './workflow_utils';
import { getMessagesToProcess } from './messages_utils';

// Client capabilities is how gitlab-lsp/browser -> workhorse -> Duo Workflow Service communicates
// capabilities that can be used by Duo Workflow Service without breaking
// backwards compatibility. We intersect the capabilities of all parties and
// then new behaviour can only depend on that behaviour if it makes it all the
// way through. Whenever you add to this list you must also update the constant in
// workhorse/internal/ai_assist/duoworkflow/runner.go and gitlab-lsp before
// the feature becomes available.
export const CLIENT_CAPABILITIES = [];

export function buildWebsocketUrl({
  rootNamespaceId,
  namespaceId,
  projectId,
  userModelSelectionEnabled,
  currentModel,
  defaultModel,
}) {
  const params = new URLSearchParams();

  if (rootNamespaceId) {
    params.append(
      DUO_WORKFLOW_WEBSOCKET_PARAM_ROOT_NAMESPACE_ID,
      getIdFromGraphQLId(rootNamespaceId),
    );
  }

  if (namespaceId) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_NAMESPACE_ID, getIdFromGraphQLId(namespaceId));
  }

  if (projectId) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_PROJECT_ID, getIdFromGraphQLId(projectId));
  }

  if (
    rootNamespaceId &&
    userModelSelectionEnabled &&
    currentModel?.value &&
    currentModel?.value !== defaultModel?.value
  ) {
    params.append(DUO_WORKFLOW_WEBSOCKET_PARAM_USER_SELECTED_MODEL, currentModel.value);
  }

  params.append('client_type', 'browser');

  return params.toString()
    ? `${DUO_WORKFLOW_WEBSOCKET_BASE_URL}?${params}`
    : DUO_WORKFLOW_WEBSOCKET_BASE_URL;
}

export function buildStartRequest({
  workflowId,
  workflowDefinition,
  goal,
  approval = {},
  additionalContext,
  agentConfig,
  metadata,
}) {
  const startRequest = {
    startRequest: {
      workflowID: workflowId,
      clientVersion: DUO_WORKFLOW_CLIENT_VERSION,
      workflowDefinition: workflowDefinition || DUO_WORKFLOW_CHAT_DEFINITION,
      workflowMetadata: metadata,
      clientCapabilities: CLIENT_CAPABILITIES,
      goal,
      approval,
    },
  };

  if (additionalContext) {
    startRequest.startRequest.additionalContext = additionalContext;
  }

  if (agentConfig) {
    const parsedAgentConfig = parseDocument(agentConfig);

    startRequest.startRequest.flowConfig = parsedAgentConfig;
    startRequest.startRequest.flowConfigSchemaVersion = parsedAgentConfig.toJSON().version;
  }

  return startRequest;
}

export async function processWorkflowMessage(event, currentMessageId) {
  const action = await parseMessage(event);

  if (!action || !action.newCheckpoint) {
    return null;
  }

  const checkpoint = JSON.parse(action.newCheckpoint.checkpoint);

  const { toProcess, lastProcessedMessageId } = getMessagesToProcess(
    checkpoint.channel_values.ui_chat_log,
    currentMessageId,
  );
  const messages = WorkflowUtils.transformChatMessages(toProcess);

  return {
    messages,
    status: action.newCheckpoint.status,
    goal: action.newCheckpoint.goal,
    lastProcessedMessageId,
  };
}
