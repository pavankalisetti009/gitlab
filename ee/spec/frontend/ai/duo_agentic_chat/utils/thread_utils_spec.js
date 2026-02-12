import { resetThreadContent } from 'ee/ai/duo_agentic_chat/utils/thread_utils';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';

describe('thread_utils', () => {
  describe('resetThreadContent', () => {
    describe('when called', () => {
      it('returns clean thread content', () => {
        const result = resetThreadContent();

        expect(result).toEqual({
          multithreadedView: DUO_CHAT_VIEWS.CHAT,
        });
      });
    });
  });
});
