import {
  clearDuoChatCommands,
  sendDuoChatCommand,
  generateEventLabelFromText,
  utils,
  setAgenticMode,
  saveDuoAgenticModePreference,
} from 'ee/ai/utils';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { setCookie } from '~/lib/utils/common_utils';
import {
  DUO_AGENTIC_MODE_COOKIE,
  DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  CHAT_MODES,
} from 'ee/ai/tanuki_bot/constants';

jest.mock('~/lib/utils/common_utils', () => ({
  setCookie: jest.fn(),
  getCookie: jest.fn(),
}));

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

    describe('setAgenticMode integration', () => {
      let originalRequestIdleCallback;

      beforeEach(() => {
        originalRequestIdleCallback = window.requestIdleCallback;
        window.requestIdleCallback = (callback) => callback();

        duoChatGlobalState.isShown = false;
        duoChatGlobalState.isAgenticChatShown = false;
        duoChatGlobalState.commands = [];

        jest.clearAllMocks();
      });

      afterEach(() => {
        window.requestIdleCallback = originalRequestIdleCallback;
      });

      it('sets agentic mode to false when sending a command', () => {
        duoChatGlobalState.isShown = false;
        duoChatGlobalState.isAgenticChatShown = true;

        const command = { question: '/help', resourceId: '123' };
        sendDuoChatCommand(command);

        expect(duoChatGlobalState.isShown).toBe(true);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);

        expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, false, {
          expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
        });
      });

      it('disables agentic mode before adding command to queue', () => {
        duoChatGlobalState.isShown = false;
        duoChatGlobalState.isAgenticChatShown = true;

        const command = { question: '/help', resourceId: '123' };
        sendDuoChatCommand(command);

        expect(duoChatGlobalState.isShown).toBe(true);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);

        expect(duoChatGlobalState.commands).toContainEqual({
          question: '/help',
          resourceId: '123',
          variables: {},
        });
      });

      it('does not change state when command validation fails', () => {
        duoChatGlobalState.isShown = false;
        duoChatGlobalState.isAgenticChatShown = true;

        expect(() => {
          sendDuoChatCommand({ question: null, resourceId: '123' });
        }).toThrow('Both arguments `question` and `resourceId` are required');

        expect(duoChatGlobalState.isShown).toBe(false);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(true);
        expect(setCookie).not.toHaveBeenCalled();
      });

      it('disables agentic mode for different command types', () => {
        const commands = [
          { question: '/troubleshoot', resourceId: '1' },
          { question: '/help', resourceId: '2', variables: { foo: 'bar' } },
          { question: 'Custom question', resourceId: '3' },
        ];

        commands.forEach((command) => {
          duoChatGlobalState.isShown = false;
          duoChatGlobalState.isAgenticChatShown = true;

          sendDuoChatCommand(command);

          expect(duoChatGlobalState.isShown).toBe(true);
          expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
        });

        expect(setCookie).toHaveBeenCalledTimes(3);
        expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, false, {
          expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
        });
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

  describe('saveDuoAgenticModePreference', () => {
    it.each`
      isAgenticMode | description
      ${true}       | ${'true'}
      ${false}      | ${'false'}
    `('calls setCookie with $description value', ({ isAgenticMode }) => {
      saveDuoAgenticModePreference(isAgenticMode);

      expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, isAgenticMode, {
        expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
      });
      expect(setCookie).toHaveBeenCalledTimes(1);
    });
  });

  describe('setAgenticMode', () => {
    beforeEach(() => {
      duoChatGlobalState.isShown = false;
      duoChatGlobalState.isAgenticChatShown = false;
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      jest.clearAllMocks();
    });

    afterEach(() => {
      duoChatGlobalState.isShown = false;
      duoChatGlobalState.isAgenticChatShown = false;
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
    });

    describe('when agenticMode is true', () => {
      it('sets correct state values', () => {
        setAgenticMode({ agenticMode: true });

        expect(duoChatGlobalState.isShown).toBe(false);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(true);
      });

      it('does not save to cookie by default', () => {
        setAgenticMode({ agenticMode: true });

        expect(setCookie).not.toHaveBeenCalled();
      });

      it('saves to cookie when saveCookie is true', () => {
        setAgenticMode({ agenticMode: true, saveCookie: true });

        expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, true, {
          expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
        });
        expect(setCookie).toHaveBeenCalledTimes(1);
      });
    });

    describe('when agenticMode is false', () => {
      it('sets correct state values', () => {
        setAgenticMode({ agenticMode: false });

        expect(duoChatGlobalState.isShown).toBe(true);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
      });

      it('does not save to cookie by default', () => {
        setAgenticMode({ agenticMode: false });

        expect(setCookie).not.toHaveBeenCalled();
      });

      it('saves to cookie when saveCookie is true', () => {
        setAgenticMode({ agenticMode: false, saveCookie: true });

        expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, false, {
          expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
        });
        expect(setCookie).toHaveBeenCalledTimes(1);
      });
    });

    describe('default parameters', () => {
      it('defaults agenticMode to true when called without arguments', () => {
        setAgenticMode();

        expect(duoChatGlobalState.isShown).toBe(false);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(true);
        expect(setCookie).not.toHaveBeenCalled();
      });

      it('defaults saveCookie to false when only agenticMode is provided', () => {
        setAgenticMode({ agenticMode: false });

        expect(setCookie).not.toHaveBeenCalled();
      });
    });

    describe('state transitions', () => {
      it.each`
        initialIsShown | initialIsAgenticChatShown | agenticMode | expectedIsShown | expectedIsAgenticChatShown
        ${false}       | ${false}                  | ${true}     | ${false}        | ${true}
        ${true}        | ${false}                  | ${true}     | ${false}        | ${true}
        ${false}       | ${true}                   | ${true}     | ${false}        | ${true}
        ${true}        | ${true}                   | ${true}     | ${false}        | ${true}
        ${false}       | ${false}                  | ${false}    | ${true}         | ${false}
        ${true}        | ${false}                  | ${false}    | ${true}         | ${false}
        ${false}       | ${true}                   | ${false}    | ${true}         | ${false}
        ${true}        | ${true}                   | ${false}    | ${true}         | ${false}
      `(
        'transitions from isShown: $initialIsShown, isAgenticChatShown: $initialIsAgenticChatShown to isShown: $expectedIsShown, isAgenticChatShown: $expectedIsAgenticChatShown when agenticMode is $agenticMode',
        ({
          initialIsShown,
          initialIsAgenticChatShown,
          agenticMode,
          expectedIsShown,
          expectedIsAgenticChatShown,
        }) => {
          duoChatGlobalState.isShown = initialIsShown;
          duoChatGlobalState.isAgenticChatShown = initialIsAgenticChatShown;

          setAgenticMode({ agenticMode });

          expect(duoChatGlobalState.isShown).toBe(expectedIsShown);
          expect(duoChatGlobalState.isAgenticChatShown).toBe(expectedIsAgenticChatShown);
        },
      );
    });

    describe('chatMode', () => {
      it('sets chatMode to AGENTIC when agenticMode is true', () => {
        setAgenticMode({ agenticMode: true });

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
      });

      it('sets chatMode to CLASSIC when agenticMode is false', () => {
        setAgenticMode({ agenticMode: false });

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.CLASSIC);
      });
    });

    describe('isEmbedded parameter', () => {
      it('updates isShown and isAgenticChatShown when isEmbedded is false', () => {
        setAgenticMode({ agenticMode: true, isEmbedded: false });

        expect(duoChatGlobalState.isShown).toBe(false);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(true);
        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
      });

      it('does not update isShown and isAgenticChatShown when isEmbedded is true', () => {
        duoChatGlobalState.isShown = true;
        duoChatGlobalState.isAgenticChatShown = false;

        setAgenticMode({ agenticMode: true, isEmbedded: true });

        // Legacy properties should not be touched in embedded mode
        expect(duoChatGlobalState.isShown).toBe(true);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
        // But chatMode should still be updated
        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
      });

      it('defaults isEmbedded to false', () => {
        setAgenticMode({ agenticMode: false });

        expect(duoChatGlobalState.isShown).toBe(true);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
      });
    });
  });

  describe('sendDuoChatCommand with embedded mode', () => {
    let originalRequestIdleCallback;
    let originalGon;

    beforeEach(() => {
      originalRequestIdleCallback = window.requestIdleCallback;
      window.requestIdleCallback = (callback) => callback();
      originalGon = window.gon;

      duoChatGlobalState.isShown = false;
      duoChatGlobalState.isAgenticChatShown = false;
      duoChatGlobalState.activeTab = null;
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      duoChatGlobalState.commands = [];

      jest.clearAllMocks();
    });

    afterEach(() => {
      window.requestIdleCallback = originalRequestIdleCallback;
      window.gon = originalGon;
      duoChatGlobalState.isShown = false;
      duoChatGlobalState.activeTab = null;
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
    });

    describe('when projectStudioEnabled is false (drawer mode)', () => {
      beforeEach(() => {
        window.gon = { features: { projectStudioEnabled: false } };
      });

      it('opens drawer mode chat', () => {
        sendDuoChatCommand({ question: '/help', resourceId: '123' });

        expect(duoChatGlobalState.isShown).toBe(true);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
        expect(duoChatGlobalState.activeTab).toBeNull();
      });

      it('forces classic mode', () => {
        sendDuoChatCommand({ question: '/help', resourceId: '123' });

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.CLASSIC);
      });
    });

    describe('when projectStudioEnabled is true (embedded mode)', () => {
      beforeEach(() => {
        window.gon = { features: { projectStudioEnabled: true } };
      });

      it('opens embedded panel to chat tab', () => {
        sendDuoChatCommand({ question: '/help', resourceId: '123' });

        expect(duoChatGlobalState.activeTab).toBe('chat');
        // Legacy drawer properties should not be touched
        expect(duoChatGlobalState.isShown).toBe(false);
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
      });

      it('forces classic mode', () => {
        sendDuoChatCommand({ question: '/help', resourceId: '123' });

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.CLASSIC);
      });
    });
  });
});
