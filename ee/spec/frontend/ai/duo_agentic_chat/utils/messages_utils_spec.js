import { getMessagesToProcess } from 'ee/ai/duo_agentic_chat/utils/messages_utils';
import { MOCK_CHAT_MESSAGES } from './mock_data';

const initialIndex = -1;

describe('Messages_utils', () => {
  describe('getMessagesToProcess', () => {
    describe('default state', () => {
      it.each`
        desc                  | value
        ${'"undefined"'}      | ${undefined}
        ${'"an empty array"'} | ${[]}
      `('returns empty Array when `messages` is %desc', ({ value }) => {
        expect(getMessagesToProcess(value)).toEqual({
          toProcess: [],
          lastProcessedIndex: initialIndex,
        });
      });

      it('returns all messages on initial state', () => {
        expect(getMessagesToProcess([MOCK_CHAT_MESSAGES.prompt], initialIndex)).toEqual({
          toProcess: [MOCK_CHAT_MESSAGES.prompt],
          lastProcessedIndex: 0,
        });
      });
    });

    describe('updating the existing messages', () => {
      const currentMessages = [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming];

      it('returns single message matching the lastProcessedIndex', () => {
        const lastProcessedIndex = currentMessages.length - 1; // `agentStreaming` is the last processed

        const incomingMessages = [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentComplete];

        expect(getMessagesToProcess(incomingMessages, lastProcessedIndex)).toEqual({
          toProcess: [incomingMessages.at(-1)], // only the last agentComplete should be processed
          lastProcessedIndex, // agentComplete replaces the agentStreaming inline
        });
      });

      it('when existing message is replaced with completely different message at the same index', () => {
        const lastProcessedIndex = currentMessages.length - 1; // `agentStreaming` is the last processed

        const incomingMessages = [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.tool];

        expect(getMessagesToProcess(incomingMessages, lastProcessedIndex)).toEqual({
          toProcess: [incomingMessages.at(-1)], // only the last agentComplete should be processed
          lastProcessedIndex, // agentComplete replaces the agentStreaming inline
        });
      });

      it('returns all messages from lastProcessedIndex onwards including the last processed message', () => {
        const lastProcessedIndex = currentMessages.length - 1; // `agentStreaming` is the last processed

        const incomingMessages = [
          MOCK_CHAT_MESSAGES.user,
          MOCK_CHAT_MESSAGES.agentComplete,
          MOCK_CHAT_MESSAGES.tool,
          MOCK_CHAT_MESSAGES.request,
        ];

        expect(getMessagesToProcess(incomingMessages, lastProcessedIndex)).toEqual({
          toProcess: [
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.request,
          ], // only the last agentComplete should be processed
          lastProcessedIndex: 3,
        });
      });
    });

    describe('full cycle workflow', () => {
      it('returns correct messages on every step of a complex workflow', () => {
        // Initial user prompt
        let lastProcessedIndex;
        let toProcess;
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.prompt],
          initialIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.prompt]);
        expect(lastProcessedIndex).toBe(0);

        // User prompt returned in the checkpoint event
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.user]);
        expect(lastProcessedIndex).toBe(0);

        // Agent starts to stream
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming]);
        expect(lastProcessedIndex).toBe(1);

        // Streaming continues with a new chunk
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming1],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([
          MOCK_CHAT_MESSAGES.agentStreaming1, // at this point user doesn't need to be processed again
        ]);
        expect(lastProcessedIndex).toBe(1);

        // Streaming is done and the complete agent message arrived in the checkpoint event
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentComplete],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.agentComplete]);
        expect(lastProcessedIndex).toBe(1);

        // A tool runs automatically to get information that doesn't require approval like
        // fetching a project information
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentComplete, MOCK_CHAT_MESSAGES.tool],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.agentComplete, MOCK_CHAT_MESSAGES.tool]);
        expect(lastProcessedIndex).toBe(2);

        // Agent starts responding with additional context from the tool
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.agent2Streaming1,
          ],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.tool, MOCK_CHAT_MESSAGES.agent2Streaming1]);
        expect(lastProcessedIndex).toBe(3);

        // Agent streaming continues
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.agent2Streaming2,
          ],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.agent2Streaming2]);
        expect(lastProcessedIndex).toBe(3);

        // Sometimes, agent streamed response gets replaced with a request, instead of sending the
        // complete agent message.
        // Keep in mind that the agent message will still stay on the screen - message with the same
        // requestID but another message_type is still considered a new message.
        // So, no messages disappearing in the UI!
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.request,
          ],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.request]);
        expect(lastProcessedIndex).toBe(3);

        // User approves request, but tool fails. In this case, the checkpoint event returns 2 messages:
        // - a tool message with `status: "failure"`
        // - a new agent message with some explanation or next step
        ({ toProcess, lastProcessedIndex } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.request,
            MOCK_CHAT_MESSAGES.tool3Fail[0],
            MOCK_CHAT_MESSAGES.tool3Fail[1],
          ],
          lastProcessedIndex,
        ));
        expect(toProcess).toEqual([
          MOCK_CHAT_MESSAGES.request,
          MOCK_CHAT_MESSAGES.tool3Fail[0],
          MOCK_CHAT_MESSAGES.tool3Fail[1],
        ]);
        expect(lastProcessedIndex).toBe(5);
      });
    });
  });
});
