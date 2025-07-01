import { AgenticDuoChat } from '@gitlab/duo-ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import DuoAgenticChatApp from 'ee/ai/duo_agentic_chat/components/app.vue';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
} from 'ee/ai/constants';
import { WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';

const MOCK_PROJECT_ID = 'gid://gitlab/Project/123';
const MOCK_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflow/456';
const MOCK_USER_MESSAGE = {
  content: 'How can I optimize my CI pipeline?',
  role: 'user',
  requestId: `${MOCK_WORKFLOW_ID}-0`,
};
const MOCK_CONTEXT_PRESETS_RESPONSE = {
  data: {
    aiChatContextPresets: {
      questions: [
        'How can I optimize my CI pipeline?',
        'What are best practices for merge requests?',
        'How do I set up a workflow for my project?',
        'What are the advantages of using GitLab CI/CD?',
      ],
    },
  },
};
const MOCK_WORKFLOW_MUTATION_RESPONSE = {
  data: {
    aiDuoWorkflowCreate: {
      workflow: {
        id: MOCK_WORKFLOW_ID,
      },
      errors: [],
    },
  },
};

class MockWebSocket {
  constructor() {
    this.onopen = null;
    this.onclose = null;
    this.onmessage = null;
    this.onerror = null;
    this.readyState = WebSocket.OPEN;
  }

  send(data) {
    this.lastSentData = data;
  }

  close() {
    if (this.onclose) {
      this.onclose();
    }
  }

  mockReceiveMessage(data) {
    if (this.onmessage) {
      const messageEvent = {
        data: {
          text: () => Promise.resolve(data),
        },
      };
      this.onmessage(messageEvent);
    }
  }

  mockError(error) {
    if (this.onerror) {
      this.onerror(error);
    }
  }
}

Vue.use(Vuex);
Vue.use(VueApollo);

describe('Duo Agentic Chat', () => {
  let wrapper;
  let mockWebSocket;

  const actionSpies = {
    addDuoChatMessage: jest.fn(),
    setMessages: jest.fn(),
    setLoading: jest.fn(),
  };

  const duoWorkflowMutationHandlerMock = jest
    .fn()
    .mockResolvedValue(MOCK_WORKFLOW_MUTATION_RESPONSE);
  const contextPresetsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_CONTEXT_PRESETS_RESPONSE);

  const findDuoChat = () => wrapper.findComponent(AgenticDuoChat);

  global.WebSocket = jest.fn().mockImplementation(() => {
    mockWebSocket = new MockWebSocket();
    return mockWebSocket;
  });

  const createComponent = ({
    initialState = {},
    propsData = { projectId: MOCK_PROJECT_ID },
    data = {},
  } = {}) => {
    const store = new Vuex.Store({
      actions: actionSpies,
      state: {
        ...initialState,
      },
    });

    const apolloProvider = createMockApollo([
      [duoWorkflowMutation, duoWorkflowMutationHandlerMock],
      [getAiChatContextPresets, contextPresetsQueryHandlerMock],
    ]);

    if (duoChatGlobalState.isAgenticChatShown !== false) {
      duoChatGlobalState.isAgenticChatShown = true;
    }

    wrapper = shallowMountExtended(DuoAgenticChatApp, {
      store,
      apolloProvider,
      propsData,
      data() {
        return data;
      },
    });
  };

  afterEach(() => {
    jest.clearAllMocks();
    duoChatGlobalState.isAgenticChatShown = false;
  });

  describe('rendering', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isAgenticChatShown = true;
      });

      it('renders the AgenticDuoChat component', () => {
        expect(findDuoChat().exists()).toBe(true);
      });

      it('calls the context presets GraphQL query when component loads', () => {
        expect(contextPresetsQueryHandlerMock).toHaveBeenCalledWith({
          projectId: MOCK_PROJECT_ID,
          url: 'http://test.host/',
          questionCount: 4,
        });
      });

      it('passes context presets to AgenticDuoChat component as predefinedPrompts', async () => {
        await waitForPromises();
        expect(findDuoChat().props('predefinedPrompts')).toEqual(
          MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions,
        );
      });
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isAgenticChatShown = false;
      });

      it('does not render the AgenticDuoChat component', () => {
        expect(findDuoChat().exists()).toBe(false);
      });

      it('does not call the context presets GraphQL query', () => {
        expect(contextPresetsQueryHandlerMock).not.toHaveBeenCalled();
      });
    });
  });

  describe('events handling', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isAgenticChatShown = true;
    });

    describe('@chat-hidden', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('chat-hidden');
        await nextTick();
      });

      it('closes the chat on @chat-hidden', () => {
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
        expect(findDuoChat().exists()).toBe(false);
      });
    });

    describe('@send-chat-prompt', () => {
      it.each([GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'resets chat state when "%s" command is sent',
        async (command) => {
          createComponent();
          wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

          findDuoChat().vm.$emit('send-chat-prompt', command);
          await nextTick();

          expect(wrapper.vm.workflowId).toBe(null);
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
        },
      );

      it('creates a new workflow when sending a prompt for the first time', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(duoWorkflowMutationHandlerMock).toHaveBeenCalledWith({
          projectId: MOCK_PROJECT_ID,
          goal: MOCK_USER_MESSAGE.content,
          workflowDefinition: 'chat',
          agentPrivileges: [3],
          preApprovedAgentPrivileges: [3],
        });

        expect(global.WebSocket).toHaveBeenCalledWith('/api/v4/ai/duo_workflows/ws');
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
            role: 'user',
            requestId: expect.stringContaining('-'),
          }),
        );
      });

      it('sets loading to true when sending a prompt', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await nextTick();

        expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), true);
      });

      it('does not create a new workflow if one already exists', async () => {
        wrapper.vm.workflowId = '456';

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(duoWorkflowMutationHandlerMock).not.toHaveBeenCalled();
        expect(global.WebSocket).toHaveBeenCalledWith('/api/v4/ai/duo_workflows/ws');
      });

      it('sends the correct start request to WebSocket when open', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        mockWebSocket.onopen();

        const expectedStartRequest = {
          startRequest: {
            workflowID: '456',
            clientVersion: '1.0',
            workflowDefinition: 'chat',
            goal: MOCK_USER_MESSAGE.content,
          },
        };

        expect(mockWebSocket.lastSentData).toBe(JSON.stringify(expectedStartRequest));
      });
    });

    describe('WebSocket message handling', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        wrapper.vm.workflowId = '456';
      });

      it('processes messages from the WebSocket and updates the UI', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  { content: 'Hello, how can I help?', message_type: 'agent' },
                  {
                    content: 'I can assist with optimizing your CI pipeline.',
                    message_type: 'agent',
                  },
                ],
              },
            }),
          },
        };

        mockWebSocket.mockReceiveMessage(JSON.stringify(mockCheckpointData));
        await waitForPromises();

        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          expect.arrayContaining([
            expect.objectContaining({
              content: 'Hello, how can I help?',
              message_type: 'assistant',
              role: 'assistant',
              requestId: '456-0',
            }),
            expect.objectContaining({
              content: 'I can assist with optimizing your CI pipeline.',
              message_type: 'assistant',
              role: 'assistant',
              requestId: '456-1',
            }),
          ]),
        );

        expect(mockWebSocket.lastSentData).toBe(
          JSON.stringify({ actionResponse: { requestID: 'request-id-1' } }),
        );
      });

      it('handles tool messages in the chat log', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-2',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Using tool to search issues',
                    message_type: 'tool',
                    tool_info: { name: 'search_issues' },
                  },
                ],
              },
            }),
          },
        };

        mockWebSocket.mockReceiveMessage(JSON.stringify(mockCheckpointData));
        await waitForPromises();

        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          expect.arrayContaining([
            expect.objectContaining({
              content: 'Using tool to search issues',
              message_type: 'tool',
              role: 'tool',
              tool_info: { name: 'search_issues' },
              requestId: '456-0',
            }),
          ]),
        );
      });

      it('handles errors from WebSocket', () => {
        const error = new Error('WebSocket error');
        mockWebSocket.mockError(error);

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: [error.toString()],
          }),
        );
      });
    });

    describe('@chat-cancel', () => {
      it('cancels the active connection and resets state', async () => {
        wrapper.vm.workflowId = '456';
        wrapper.vm.socket = mockWebSocket;

        const socketCloseSpy = jest.spyOn(mockWebSocket, 'close');

        findDuoChat().vm.$emit('chat-cancel');
        await nextTick();

        expect(socketCloseSpy).toHaveBeenCalled();
        expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
        expect(wrapper.vm.workflowId).toBe(null);
      });
    });

    describe('@new-chat', () => {
      it('resets chat state for new conversation', async () => {
        wrapper.vm.workflowId = '456';

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(wrapper.vm.workflowId).toBe(null);
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
        expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Failed to fetch resources';

    it('handles errors from the context presets query', async () => {
      contextPresetsQueryHandlerMock.mockRejectedValue(new Error(errorText));
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      expect(findDuoChat().exists()).toBe(true);
      expect(findDuoChat().props('predefinedPrompts')).toEqual([]);
    });

    it('handles workflow mutation errors', async () => {
      duoWorkflowMutationHandlerMock.mockRejectedValue(new Error(errorText));
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });
  });

  describe('Resizable Dimensions', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
    });

    it('initializes dimensions correctly on mount', () => {
      expect(wrapper.vm.width).toBe(550);
      expect(wrapper.vm.height).toBe(window.innerHeight);
      expect(wrapper.vm.maxWidth).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.maxHeight).toBe(window.innerHeight);
    });

    it('updates dimensions correctly when `chat-resize` event is emitted', async () => {
      const newWidth = 600;
      const newHeight = 500;
      const chat = findDuoChat();
      chat.vm.$emit('chat-resize', { width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(newWidth);
      expect(wrapper.vm.height).toBe(newHeight);
    });

    it('ensures dimensions do not exceed maxWidth or maxHeight', async () => {
      const newWidth = window.innerWidth + 100;
      const newHeight = window.innerHeight + 100;
      const chat = findDuoChat();

      chat.vm.$emit('chat-resize', { width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.height).toBe(window.innerHeight);
    });

    it('updates dimensions when the window is resized', async () => {
      const originalInnerWidth = window.innerWidth;
      const originalInnerHeight = window.innerHeight;

      try {
        window.innerWidth = 1200;
        window.innerHeight = 800;

        window.dispatchEvent(new Event('resize'));
        await nextTick();

        expect(wrapper.vm.maxWidth).toBe(1200 - WIDTH_OFFSET);
        expect(wrapper.vm.maxHeight).toBe(800);
      } finally {
        window.innerWidth = originalInnerWidth;
        window.innerHeight = originalInnerHeight;
      }
    });
  });

  describe('Global state watchers', () => {
    describe('duoChatGlobalState.isAgenticChatShown', () => {
      it('creates a new chat when Duo Chat is closed', async () => {
        duoChatGlobalState.isAgenticChatShown = true;
        createComponent();
        wrapper.vm.workflowId = '456';

        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        duoChatGlobalState.isAgenticChatShown = false;
        await nextTick();

        expect(onNewChatSpy).toHaveBeenCalled();
        expect(wrapper.vm.workflowId).toBe(null);
      });

      it('does not create a new chat when Duo Chat is opened', async () => {
        duoChatGlobalState.isAgenticChatShown = false;
        createComponent();

        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        duoChatGlobalState.isAgenticChatShown = true;
        await nextTick();

        expect(onNewChatSpy).not.toHaveBeenCalled();
      });
    });
  });
});
