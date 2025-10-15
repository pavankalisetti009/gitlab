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
      goal,
      approval,
    },
  };

  if (additionalContext) {
    startRequest.startRequest.additionalContext = additionalContext;
  }

  if (agentConfig) {
    startRequest.startRequest.flowConfig = parseDocument(agentConfig);
    startRequest.startRequest.flowConfigSchemaVersion = 'experimental';
  }

  return startRequest;
}

export async function processWorkflowMessage(event, workflowId) {
  const action = await parseMessage(event);

  if (!action || !action.newCheckpoint) {
    return null;
  }

  const checkpoint = JSON.parse(action.newCheckpoint.checkpoint);
  const messages = WorkflowUtils.transformChatMessages(
    checkpoint.channel_values.ui_chat_log,
    workflowId,
  );

  return {
    messages,
    status: action.newCheckpoint.status,
    goal: action.newCheckpoint.goal,
  };
}
