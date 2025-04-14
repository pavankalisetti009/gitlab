import {
  clearDuoChatCommands,
  sendDuoChatCommand,
  generateEventLabelFromText,
  utils,
} from 'ee/ai/utils';
import { duoChatGlobalState } from '~/super_sidebar/constants';

describe('AI Utils', () => {
  describe('concatStreamedChunks', () => {
    it.each`
      input                        | expected
      ${[]}                        | ${''}
      ${['']}                      | ${''}
      ${[undefined, 'foo']}        | ${''}
      ${['foo', 'bar']}            | ${'foobar'}
      ${['foo', '', 'bar']}        | ${'foo'}
      ${['foo', undefined, 'bar']} | ${'foo'}
      ${['foo', ' ', 'bar']}       | ${'foo bar'}
      ${['foo', 'bar', undefined]} | ${'foobar'}
    `('correctly concatenates streamed chunks', ({ input, expected }) => {
      expect(utils.concatStreamedChunks(input)).toBe(expected);
    });
  });

  describe('sendDuoChatCommand', () => {
    describe('arguments validation', () => {
      it.each`
        question       | resourceId
        ${null}        | ${null}
        ${null}        | ${'1'}
        ${'/feedback'} | ${null}
      `(
        'throws an error if args are question: $question, resourceId: $resourceId',
        ({ question, resourceId }) => {
          expect(() => {
            sendDuoChatCommand({ question, resourceId });
          }).toThrow('Both arguments `question` and `resourceId` are required');
        },
      );

      it('does not throw with valid arguments', () => {
        expect(() => {
          sendDuoChatCommand({ question: '/feedback', resourceId: '1' });
        }).not.toThrow();
      });
    });

    describe('commands', () => {
      const newCommand = { question: 'new', resourceId: '2', variables: { otherStuff: '' } };
      let originalRequestIdleCallback;

      beforeEach(() => {
        originalRequestIdleCallback = window.requestIdleCallback;
        window.requestIdleCallback = (callback) => callback();
      });

      afterEach(() => {
        duoChatGlobalState.commands = [];
        window.requestIdleCallback = originalRequestIdleCallback;
      });

      it.each`
        commands | text
        ${[]}    | ${'in an empty array'}
        ${[]}    | ${'in an array with items'}
      `('Adds new command to existing commands $text', ({ commands }) => {
        duoChatGlobalState.commands = [...commands];
        sendDuoChatCommand(newCommand);
        expect(duoChatGlobalState.commands).toEqual([...commands, newCommand]);
      });
    });
  });

  describe('Duo chat visibility', () => {
    afterEach(() => {
      duoChatGlobalState.isShown = false;
    });

    describe('when the chat is already shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = true;
      });

      it('does not change the isShown value', () => {
        sendDuoChatCommand({ question: 'hello', resourceId: '1' });
        expect(duoChatGlobalState.isShown).toBe(true);
      });
    });

    describe('when the chat is not shown', () => {
      it('sets the isShown value to true', () => {
        sendDuoChatCommand({ question: 'hello', resourceId: '1' });
        expect(duoChatGlobalState.isShown).toBe(true);
      });
    });
  });

  describe('clearDuoChatCommands', () => {
    beforeEach(() => {
      duoChatGlobalState.commands = [
        { question: '/troubleshoot', resourceId: '1' },
        { question: '/action', resourceId: '2' },
      ];
    });

    afterEach(() => {
      duoChatGlobalState.commands = [];
    });

    it('clears all existing commands', () => {
      clearDuoChatCommands();
      expect(duoChatGlobalState.commands).toEqual([]);
    });
  });

  describe('generateEventLabelFromText', () => {
    it.each([
      {
        input: 'What are the main points from this MR discussion?',
        expected: 'what_are_the_main_points_from_this_mr_discussion',
      },
      {
        input: "What's going on with this code?!",
        expected: 'whats_going_on_with_this_code',
      },
      {
        input:
          'A very long string that should be truncated because it exceeds the maximum length of fifty characters',
        expected: 'a_very_long_string_that_should_be_truncated_becaus',
      },
    ])('converts "$input" to "$expected"', ({ input, expected }) => {
      expect(generateEventLabelFromText(input)).toBe(expected);
    });
  });
});
