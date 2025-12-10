import {
  getWorkflowIdFromThreadId,
  parseThreadForSelection,
  resetThreadContent,
} from 'ee/ai/duo_agentic_chat/utils/thread_utils';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';

describe('thread_utils', () => {
  describe('getWorkflowIdFromThreadId', () => {
    it('returns the workflow ID from a thread ID', () => {
      const threadId = 'gid://gitlab/DuoWorkflowWorkflow/123';
      expect(getWorkflowIdFromThreadId(threadId)).toBe('123');
    });
    it('returns null if the input is not a valid GID', () => {
      expect(getWorkflowIdFromThreadId('invalid-id')).toBeNull();
    });
    it('returns null if the thread ID is undefined', () => {
      expect(getWorkflowIdFromThreadId(undefined)).toBeNull();
    });
  });

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
          multithreadedView: DUO_CHAT_VIEWS.CHAT,
        });
      });
    });
  });
});
