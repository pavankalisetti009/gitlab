import { parseGid } from '~/graphql_shared/utils';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';

export function parseThreadForSelection(thread) {
  return {
    activeThread: thread.id,
    workflowId: parseGid(thread.id).id,
  };
}

export function resetThreadContent() {
  return {
    activeThread: undefined,
    chatMessageHistory: [],
    multithreadedView: DUO_CHAT_VIEWS.CHAT,
  };
}
