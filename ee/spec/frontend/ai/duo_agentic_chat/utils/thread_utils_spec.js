import {
  parseThreadForSelection,
  resetThreadContent,
} from 'ee/ai/duo_agentic_chat/utils/thread_utils';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';

describe('thread_utils', () => {
  describe('parseThreadForSelection', () => {
    describe('when thread has valid GID', () => {
      it('extracts activeThread and workflowId', () => {
        const thread = {
          id: 'gid://gitlab/DuoWorkflowWorkflow/123',
        };

        const result = parseThreadForSelection(thread);

        expect(result).toEqual({
          activeThread: 'gid://gitlab/DuoWorkflowWorkflow/123',
          workflowId: '123',
        });
      });
    });
  });

  describe('resetThreadContent', () => {
    describe('when called', () => {
      it('returns clean thread content', () => {
        const result = resetThreadContent();

        expect(result).toEqual({
          activeThread: undefined,
          chatMessageHistory: [],
          multithreadedView: DUO_CHAT_VIEWS.CHAT,
        });
      });
    });
  });
});
