import { parseGid } from '~/graphql_shared/utils';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';

export function getWorkflowIdFromThreadId(threadId) {
  return parseGid(threadId)?.id || null;
}

export function parseThreadForSelection(thread) {
  return {
    activeThread: thread.id,
    workflowId: getWorkflowIdFromThreadId(thread.id),
  };
}

export function resetThreadContent() {
  return {
    activeThread: undefined,
    multithreadedView: DUO_CHAT_VIEWS.CHAT,
  };
}
