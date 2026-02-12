import { DUO_CHAT_VIEWS } from 'ee/ai/constants';

export function resetThreadContent() {
  return {
    multithreadedView: DUO_CHAT_VIEWS.CHAT,
  };
}
